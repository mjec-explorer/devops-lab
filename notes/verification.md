# Verification
This document records how each component of the system was validated during development.
## Tool versions
- git: 2.34.1
- docker: 28.2.2
- docker compose: 2.39.1-desktop.1
---

## CI Pipeline Validation

Trigger the Jenkins pipeline.

Expected stages:

* Checkout
* Unit Tests
* Build Image
* Push Image
* Deploy

The Jenkins console output should show each stage completing successfully.

---

## Image Validation

Confirm the image exists in the container registry.

Example:

```
docker pull ghcr.io/mjec-explorer/devops-lab-app:<git-sha>
```

Successful pull confirms the build and push stages worked.

---

## Deployment Validation

Check running containers:

```
docker compose ps
```

Expected services:

* app
* nginx
* prometheus
* grafana
* alertmanager
* node-exporter

The application container should show:

```
healthy
```

---

## Application Health Check

Test the health endpoint:

```
curl http://localhost/health
```

Expected output:

```
{"status":"ok"}
```

---

## Reverse Proxy Validation

Requests to nginx should reach the FastAPI service.

Test:

```
curl http://localhost
```

If nginx is configured correctly, the request is forwarded to the application container.

---

## Monitoring Validation

Open Prometheus:

```
http://localhost:9090
```

Navigate to:

```
Status → Targets
```

Expected targets:

* FastAPI metrics endpoint
* Node Exporter

Both should show:

```
UP
```

---

## Alert Validation

Simulate failure:

```
docker stop devops_lab-app-1
```

Expected behavior:

* Prometheus detects failure
* alert rule triggers
* Alertmanager sends notification to Slack

---

## Recovery Validation

Restart container:

```
docker compose up -d app
```

Verify:

* health endpoint returns OK
* Prometheus target returns UP
