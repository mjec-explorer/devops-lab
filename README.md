# DevOps Lab: Production-Grade Self-Healing Infrastructure with Automated Remediation

This project demonstrates a production-style system that detects failures, attempts automated remediation, verifies recovery, and falls back to direct alerting when automation fails.

It is designed to reflect how real engineering systems behave under failure, not just how they run when everything works.

Every component was built, broken, debugged, and rebuilt to understand the full lifecycle from deployment to incident response.

---

## Architecture

### Full Stack Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        CI/CD PIPELINE                           │
│                                                                 │
│  Git Push → Jenkins → Unit Tests → Build Image → Tag (SHA)      │
│                  → Push GHCR → Deploy → Health Check → Live     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      RUNTIME STACK                              │
│                                                                 │
│  Browser/Client                                                 │
│       │                                                         │
│       ▼                                                         │
│  Nginx (port 80) ──────────────────► FastAPI (port 8000)        │
│                                         │                       │
│                                    /health  /metrics            │
└─────────────────────────────────────────────────────────────────┘
                              │
                         /metrics
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   OBSERVABILITY STACK                           │
│                                                                 │
│  Prometheus (scrapes every 15s)                                 │
│    ├── FastAPI /metrics          (application metrics)          │
│    ├── Node Exporter :9100       (host metrics)                 │
│    └── Blackbox Exporter :9115   (HTTP probe results)           │
│          └── probes: n8n, grafana, app health                   │
│                                                                 │
│  Grafana ◄──── queries ──── Prometheus                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                         alert rules
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ALERT & AUTOMATION                           │
│                                                                 │
│  Alertmanager                                                   │
│    ├── WARNING  ──────────────────────────────► Slack           │
│    └── CRITICAL                                                 │
│         ├── n8n webhook ──► Parse & Enrich                      │
│         │                       │                               │
│         │              Is Critical?                             │
│         │                  YES                                  │
│         │                   ├── Notify Slack (enriched)         │
│         │                   ├── Restart Container               │
│         │                   │   (via Docker Socket Proxy)       │
│         │                   ├── Wait 30s                        │
│         │                   ├── Health Check (Prometheus API)   │
│         │                   ├── RECOVERED → Slack ✓            │
│         │                   └── FAILED    → Escalate ⚠         │
│         │                                                       │
│         └── slack-backup ─────────────────► Slack (fallback)    │
│              (when n8n is down)                                 │
│                                                                 │
│  Blackbox detects n8n down → N8NDown alert → fallback active    │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                  AWS INFRASTRUCTURE (Terraform)                 │
│                                                                 │
│  VPC (10.0.0.0/16) — eu-central-1 Frankfurt                     │
│    └── Public Subnet (10.0.1.0/24) — eu-central-1a              │
│         ├── Internet Gateway                                    │
│         ├── Route Table (0.0.0.0/0 → IGW)                       │
│         ├── Security Group (ports 22, 80, 443)                  │
│         └── EC2 t3.micro — Ubuntu 22.04                         │
└─────────────────────────────────────────────────────────────────┘
```

### Alert Routing Logic

```
Alert fires in Prometheus
        │
        ▼
Alertmanager receives alert
        │
        ├── severity = warning
        │       └── default receiver → n8n → Slack (notify only)
        │
        └── severity = critical
                ├── child route 1 → n8n-webhook (continue: true)
                │       └── n8n handles enrichment + remediation
                └── child route 2 → slack-backup
                        └── direct Slack delivery (guaranteed)
```

### CI/CD Pipeline Stages

```
Stage 1: Checkout         — pull source code from GitHub
Stage 2: Unit Tests       — run pytest inside Docker test container
Stage 3: Build Image      — multi-stage Docker build (test → production)
Stage 4: Tag with SHA     — tag image with Git commit SHA
Stage 5: Push to GHCR     — push to GitHub Container Registry
Stage 6: Deploy           — docker compose up with new image
Stage 7: Health Check     — wait for container to report healthy
Stage 8: Verify Endpoint  — curl /health, confirm {"status":"ok"}
```

---

## Stack

| Component | Role |
|---|---|
| FastAPI | Application — exposes /health and /metrics endpoints |
| Nginx | Reverse proxy — single entry point, routes to application |
| Jenkins | CI/CD — builds, tests, tags, pushes, deploys, validates |
| GitHub Container Registry | Image storage — tagged with Git commit SHA |
| Prometheus | Metrics collection and alert rule evaluation |
| Node Exporter | Host metrics — CPU, memory, disk, network |
| Blackbox Exporter | External HTTP probing — monitors services from outside |
| Grafana | Metrics visualisation and dashboards |
| Alertmanager | Alert routing, deduplication, grouping, fallback delivery |
| n8n | Alert enrichment, automated remediation, incident workflow |
| Docker Socket Proxy | Controlled Docker API access for safe container operations |
| Terraform | AWS infrastructure as code |
| AWS EC2 | Cloud compute provisioned and managed by Terraform |

---

## CI/CD Pipeline

The Jenkins pipeline runs on every commit and follows a defined sequence. Each stage must pass before the next begins.

A deployment that passes unit tests but produces an unhealthy container does not go live. The health check gate enforces this automatically. Tagging with the Git SHA means every running image can be traced back to the exact commit that produced it.

---

## Monitoring and Observability

Prometheus scrapes metrics every 15 seconds from three sources.

**Application metrics** — request counts, error rates, and latency from the FastAPI application via the /metrics endpoint.

**Host metrics** — CPU, memory, disk, and network from Node Exporter running on the host system.

**External probes** — Blackbox Exporter checks whether HTTP endpoints are actually reachable from the outside. This catches scenarios where a service is running but not responding — something internal scraping would miss.

---

## Alert Rules

| Alert | Condition | Severity | Action |
|---|---|---|---|
| InstanceWarning | Service unreachable for 2 minutes | Warning | Notify only |
| InstanceDown | Service unreachable for 5 minutes | Critical | Auto-remediate |
| HighErrorRate | Error rate exceeds 5% for 2 minutes | Critical | Notify |
| NoTraffic | No requests received for 5 minutes | Warning | Notify |
| N8NDown | n8n HTTP endpoint unreachable for 1 minute | Critical | Fallback delivery |

The gap between InstanceWarning and InstanceDown gives time to investigate before automated action is taken.

---

## Incident Automation Pipeline

Alerts route through n8n which handles enrichment, decision-making, and action.

```
Alert received from Alertmanager
    Parse and enrich the payload
        Add Grafana dashboard URL
        Add runbook link
        Map instance to container name
    Is this alert firing?
        Yes — Is it critical severity?
            Yes:
                Notify Slack with full context
                Call Docker API to restart the container
                Wait 30 seconds
                Query Prometheus API to verify recovery
                    Recovered → post recovery timeline to Slack
                    Still down → escalate to critical channel
            No (warning):
                Notify Slack
                No automated action
        No (resolved):
            Post resolved notification
```

If n8n goes down, Blackbox Exporter detects the failure and Prometheus fires the N8NDown alert. Alertmanager then delivers directly to Slack without passing through n8n.

---

## Key Design Decisions

**Why separate Alertmanager from n8n?**
Alertmanager handles reliability — deduplication, grouping, silencing, delivery guarantees. n8n handles intelligence — enrichment, logic, remediation. Each component does one thing and does it well. If n8n fails, Alertmanager still delivers through the fallback path.

**Why Docker Socket Proxy?**
Mounting /var/run/docker.sock directly gives a container unrestricted root-level access to the entire Docker daemon. The socket proxy exposes only the specific API endpoints needed — container restart. Principle of least privilege applied to container access.

**Why Blackbox Exporter for n8n monitoring?**
n8n does not expose a Prometheus metrics endpoint. Internal scraping would always show the target as down. Blackbox probes the HTTP port directly, detecting failure the same way an external caller would experience it.

**Why Git SHA tagging?**
Tags like `latest` tell you nothing about what is running. A Git SHA tells you the exact commit. If a deployment causes an incident, you identify the change in seconds and roll back to the previous SHA.

**Why dual delivery for critical alerts?**
n8n delivers enriched contextual notifications. The direct Alertmanager path delivers when n8n is unavailable. Critical alerts should never be silently dropped.

---

## AWS Infrastructure with Terraform

Real AWS infrastructure provisioned with Terraform in eu-central-1 Frankfurt.

```bash
cd terraform
terraform init
terraform plan
terraform apply
ssh -i ~/.ssh/devopslab ubuntu@$(terraform output -raw ec2_public_ip)
```

Always run `terraform plan` before `terraform apply`. The plan shows exactly what will change before anything happens.

---

## Running the Stack

```bash
docker compose up -d
docker compose ps
curl http://localhost/health
```

| Service | URL |
|---|---|
| Application | http://localhost |
| Prometheus | http://localhost:9090 |
| Grafana | http://localhost:3000 |
| Alertmanager | http://localhost:9093 |
| n8n | http://localhost:5678 |
| Jenkins | http://localhost:8080 |
| Blackbox | http://localhost:9115 |

---

## Testing the Incident Pipeline

```bash
docker compose stop node-exporter
```

4Watch Slack without touching anything else. A warning fires. After the threshold window, a critical alert fires and remediation starts automatically. The container restarts. A health check confirms recovery. A recovery notification posts to Slack with the full incident timeline. No manual intervention.

---

## Repository Structure

```
devops-lab/
    app/                    FastAPI application and unit tests
    alertmanager/           Alert routing and fallback configuration
    prometheus/             Scrape config, blackbox targets, alert rules
    blackbox/               HTTP probe module configuration
    nginx/                  Reverse proxy configuration
    jenkins/                Jenkins image with Docker socket access
    terraform/              AWS infrastructure as code4
    notes/                  Architecture decisions and verification guide
    docker-compose.yml      Full local stack definition
    docker-compose.cicd.yml Jenkins auxiliary stack
    Jenkinsfile             CI/CD pipeline stages
```

---

## Known Limitations

**Single Alertmanager instance** — no high availability. Production fix is a three-node cluster with gossip protocol for state sharing. Planned for Kubernetes migration.

**n8n as automation layer** — lacks guaranteed delivery semantics. Production environments would augment with a managed service like PagerDuty for on-call management.

**Local Terraform state** — works for solo development, fails in team environments. Production fix is remote state in S3 with DynamoDB locking. This is the next Terraform milestone.

**SSH open to 0.0.0.0/0** — acceptable for a lab. Production fix is restricting to specific IPs or using AWS Systems Manager Session Manager with no open port 22.

---

## Roadmap

**Phase 1 — CI/CD and Monitoring** ✅ Complete

**Phase 2 — Intelligent Incident Automation** (In progress)

Alert enrichment, automated remediation, escalation paths, and meta-monitoring complete. Incident logging, alert deduplication, Jenkins failure handling, and Jira integration coming next.

**Phase 3 — AWS Infrastructure with Terraform** (In progress)

Core networking and compute provisioned. Remote state, private subnets, NAT Gateway, ECS deployment, and load balancing coming next.

**Phase 4 — Kubernetes** (Planned)

Migrate the full stack to Kubernetes on EKS. Alertmanager HA cluster. CKA certification.

**Phase 5 — Security and Compliance** (Planned)

HashiCorp Vault for secrets management. IAM least privilege hardening. Audit logging.

---

## What Building This Taught

Every configuration setting is a deliberate trade-off. Scrape intervals, evaluation windows, group waits — each one affects how fast a failure becomes visible before anyone is paged.

Coming from a background where the response side was the job, building this stack gave visibility into the machine side of MTTD and MTTR. Understanding both sides of that equation changed how I think about observability tools — not just what thresholds to set, but how the full path from failure to awareness to action works, and how to engineer each step deliberately.

---

[Architecture Decisions](notes/decisions.md) · [System Verification](notes/verification.md)

Portfolio: https://mjec-explorer.github.io

LinkedIn: https://linkedin.com/in/mjcastro-itops
