# System Verification

This document is a step-by-step guide to verifying that every component of the system is working correctly. 

---

## Tool Versions

- git: 2.34.1
- docker: 28.2.2
- docker compose: 2.39.1
- terraform: 1.14.7
- aws cli: 2.34.12

---

## 1. Start the Stack

```bash
docker compose up -d
docker compose ps
```

All containers should show as running. The app container should show `(healthy)`.

Expected containers:

```
devops_lab-app-1          healthy
devops_lab-nginx-1        running
devops_lab-prometheus-1   running
devops_lab-grafana-1      running
devops_lab-alertmanager-1 running
devops_lab-node-exporter-1 running
devops_lab-blackbox-1     running
devops_lab-n8n-1          running
devops_lab-docker-proxy-1 running
```

---

## 2. Application Health Check

```bash
curl http://localhost/health
```

Expected:

```json
{"status":"ok"}
```

This confirms Nginx is routing traffic to the FastAPI container correctly.

---

## 3. Prometheus Targets

Open `http://localhost:9090/targets`

All targets should show state `UP`:

- prometheus (self-scrape)
- fastapi (app:8000)
- node-exporter (node-exporter:9100)
- blackbox probes for n8n, grafana, and app health endpoint

If any target shows `DOWN`, check the container is running and the scrape config is correct.

```bash
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"health"'
```

All values should be `"up"`.

---

## 4. Alert Rules Loaded

```bash
curl -s http://localhost:9090/api/v1/rules | python3 -m json.tool | grep '"name"'
```

Expected alert names:

- InstanceWarning
- InstanceDown
- HighErrorRate
- NoTraffic
- N8NDown

Validate the config file directly:

```bash
docker exec devops_lab-prometheus-1 promtool check config /etc/prometheus/prometheus.yml
```

Expected: `SUCCESS`

---

## 5. Alertmanager Config

```bash
docker exec devops_lab-alertmanager-1 amtool check-config /etc/alertmanager/alertmanager.yml
```

Expected: `SUCCESS` with correct number of receivers.

Check active alerts (should be empty when everything is healthy):

```bash
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
```

Expected: `[]`

---

## 6. Grafana

Open `http://localhost:3000`

Login with default credentials (admin/admin on first launch).

Verify the Prometheus data source is connected:

Settings → Data Sources → Prometheus → Test

Expected: `Data source is working`

---

## 7. n8n Workflow

Open `http://localhost:5678`

Verify the Alert Automation workflow is published (green Published indicator top right).

The workflow should show all nodes connected:

```
Alert Receiver → Parse & Enrich Alert → Is Firing? → Is Critical? → Restart Container → Wait for Recovery → Health Check → Is Recovered? → Notify Slack
```

---

## 8. Full Incident Lifecycle Test

This is the end-to-end test. Run it to confirm the entire pipeline works.

```bash
# Note the time
echo "$(date '+%H:%M:%S') - Stopping node-exporter"
docker compose stop node-exporter
```

Watch Slack. Expected sequence:

1. `[WARNING] InstanceWarning` — appears within seconds
2. `[FIRING] InstanceDown` — appears after threshold is met, remediation starts
3. `[RECOVERED] InstanceDown` — container restarted automatically by n8n
4. `[RESOLVED] InstanceWarning` — all clear

Verify the container came back automatically:

```bash
docker compose ps node-exporter
```

Should show `Up X seconds` — restarted by n8n without manual intervention.

Check n8n execution history at `http://localhost:5678` → Executions. The last execution should show `Succeeded` with the remediation path taken.

---

## 9. Fallback Path Test (n8n Down)

This test verifies alerts still reach Slack when n8n is unavailable.

```bash
docker compose stop n8n
docker compose stop node-exporter
```

Wait 90 seconds. Check Slack. You should see a plain `[FIRING]` message delivered directly by Alertmanager — not the enriched n8n version.

Also check that `N8NDown` alert fires:

```bash
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool | grep "alertname"
```

Should show both `InstanceDown` and `N8NDown`.

Restore:

```bash
docker compose up -d --force-recreate n8n
docker compose up -d --force-recreate node-exporter
```

---

## 10. CI/CD Pipeline

Start Jenkins if not already running:

```bash
docker compose -f docker-compose.yml -f docker-compose.cicd.yml up -d --build jenkins
```

Open `http://localhost:8080`

Run the `devops-lab-ci` pipeline. All eight stages should pass:

1. Checkout
2. Unit Tests
3. Build Image
4. Tag with Git SHA
5. Push to GHCR
6. Deploy
7. Health Validation
8. Endpoint Verification

After the pipeline completes, confirm the deployed image tag matches the current Git SHA:

```bash
git rev-parse --short HEAD
docker inspect devops_lab-app-1 | grep Image
```

The SHA in the image tag should match the Git SHA.

---

## 11. Alertmanager API Verification

After triggering an alert, verify routing is correct:

```bash
curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
```

Check the `receivers` field. Critical alerts should show both `n8n-webhook` and `slack-backup` as receivers.

---

## 12. Blackbox Probe Verification

```bash
curl -s "http://localhost:9090/api/v1/query?query=probe_success" | python3 -m json.tool
```

All probe_success values should be `"1"`. A value of `"0"` means that endpoint is unreachable.

---

## 13. AWS Infrastructure (Terraform)

```bash
cd terraform
terraform plan
```

Expected: `No changes. Your infrastructure matches the configuration.`

SSH into the EC2 instance to confirm it is reachable:

```bash
ssh -i ~/.ssh/devopslab ubuntu@$(terraform output -raw ec2_public_ip)
```

Inside the instance:

```bash
curl http://169.254.169.254/latest/meta-data/instance-type
# t3.micro

curl http://169.254.169.254/latest/meta-data/placement/availability-zone
# eu-central-1a
```

Exit the instance and confirm Terraform state is clean:

```bash
terraform state list
```

Should list all 8 resources: vpc, subnet, internet gateway, route table, route table association, security group, key pair, and EC2 instance.
