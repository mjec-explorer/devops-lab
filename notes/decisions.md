# Architecture Decisions

This document explains the technical choices made while building this DevOps lab. Every decision reflects either a deliberate trade-off, a lesson learned from something that broke, or a practice borrowed from real production environments.

---

## Why Jenkins for CI/CD

Jenkins was chosen because it is widely deployed in production environments and gives full visibility into every pipeline stage. The Jenkinsfile lives in the repository alongside the application code — infrastructure and delivery logic are version controlled together.

The pipeline runs eight stages in sequence. Each must pass before the next begins. A failed health check at stage seven stops the deployment, which means the broken version never reaches users.

The trade-off is operational overhead. Jenkins requires maintenance, plugin management, and security hardening. In a managed cloud environment, GitHub Actions or AWS CodePipeline would reduce that overhead. Jenkins was the right choice here because the goal was to understand how pipelines work internally, not to minimise configuration.

---

## Multi-Stage Docker Builds

The application Dockerfile uses two stages. The first stage runs the unit tests. The second stage builds the production image.

This means tests run as part of the build process, you cannot build a production image without tests passing first. It also means the final image contains only what the application needs to run, not the test dependencies. Smaller image, smaller attack surface, faster pulls.

---

## Git SHA Image Tagging

Every image pushed to GitHub Container Registry is tagged with the Git commit SHA that produced it.

```
ghcr.io/mjec-explorer/devops-lab-app:3609a1e
```

This makes every deployment traceable. If a production incident occurs, you can identify exactly what code is running, find the commit, and understand what changed. Rolling back means deploying the previous SHA — deterministic and reliable.

Tags like `latest` tell you nothing about what is actually running. SHA tags tell you everything.

---

## Nginx as Reverse Proxy

Nginx sits in front of the application and handles all incoming traffic on port 80. The FastAPI container is never exposed directly, it only receives traffic through Nginx on the internal Docker network.

This pattern reflects how production systems work. The public entry point is separated from the application. SSL termination, rate limiting, and routing rules live in Nginx, the application stays focused on serving requests.

The `depends_on` configuration uses `condition: service_healthy` rather than just `condition: service_started`. Nginx only begins accepting traffic after the application container passes its health check. This prevents requests from reaching an application that has started but is not yet ready.

---

## Why Separate Alertmanager from n8n

Alertmanager handles the reliability concerns of alert delivery, deduplication, grouping, silencing, inhibition, and guaranteed routing. n8n handles the intelligence layer, enrichment, conditional logic, remediation actions, and incident workflows.

Keeping these separate means the notification logic can evolve without touching the alert routing configuration. It also means if n8n goes down, Alertmanager still delivers alerts through the fallback path. Each component has one responsibility and does it well.

---

## Why n8n for Automation

n8n provides a visual workflow that makes the decision logic visible and debuggable. Every node can be inspected, every execution is logged, every step in the alert-to-action pipeline is traceable.

The trade-off is that n8n lacks the guaranteed delivery semantics and enterprise on-call features of managed services like PagerDuty. For a production environment handling critical services, the automation layer would need more robust delivery guarantees. n8n is the right choice here because the goal was to understand and demonstrate the automation logic.

---

## Docker Socket Proxy

n8n needs to restart containers as part of automated remediation. The naive approach is mounting `/var/run/docker.sock` directly into the n8n container. That gives n8n unrestricted root-level access to the Docker daemon  that could create, destroy, or modify any container on the host.

The socket proxy sits between n8n and the Docker daemon. It exposes only the specific API endpoints needed in this case, container restart. Everything else is blocked. This applies the principle of least privilege to container access.

---

## Blackbox Exporter for External Monitoring

n8n does not expose a Prometheus metrics endpoint. If we added n8n as a standard Prometheus scrape target, the `up` metric would always show 0 regardless of whether n8n is actually running because there is nothing to scrape.

Blackbox Exporter probes HTTP endpoints from the outside. It checks whether `http://n8n:5678` responds successfully, the same check an external caller would perform. This detects failure regardless of the internal reason, and it works for any service regardless of whether it exposes metrics.

The same pattern applies to any service that does not instrument itself for Prometheus. Blackbox is the right tool for availability monitoring.

---

## Dual Delivery for Critical Alerts

Critical alerts are sent through two paths simultaneously. n8n handles the enriched, contextual delivery with full automation logic. Alertmanager delivers a plain backup message directly to Slack.

This means a critical alert is never silently dropped even if n8n is unavailable. The two paths have different failure modes, n8n going down does not affect the Alertmanager direct path. The cost is two messages per critical alert, but the operational certainty is worth it.

---

## Tiered Alert Severity

InstanceWarning fires after 5 seconds of a service being unreachable. InstanceDown fires after 20 seconds. The gap between them gives time to investigate before automated action is taken.

In production these gaps would be wider, minutes rather than seconds to avoid triggering remediation on transient failures that would resolve on their own. The values here are compressed for demonstration purposes. The principle is the same: warn early, act later.

---

## Terraform for AWS Infrastructure

Infrastructure defined as code is version controlled, reproducible, and auditable. Running `terraform plan` before `terraform apply` shows exactly what will change before anything happens. This discipline prevents unintended modifications in production.

The current Terraform state is stored locally. In a team environment this would fail, two engineers running apply simultaneously would corrupt the state file. Remote state in S3 with DynamoDB locking is the production pattern and is the next milestone for this project.

---

## Why Docker Compose Over Kubernetes for This Phase

Docker Compose keeps the architecture visible. Every service, network, and volume is defined in one file. You can understand how everything connects without knowledge of Kubernetes abstractions.

Kubernetes is planned for Phase 4. The intent is to build on a foundation where every component is already understood, adding orchestration complexity on top of a system you know deeply rather than learning both simultaneously.

---

## Known Limitations

Single Alertmanager instance — no HA. Production fix is a three-node cluster with gossip protocol.

n8n as automation layer — lacks enterprise delivery guarantees. Production augmentation with PagerDuty for on-call management.

Local Terraform state — breaks in team environments. Production fix is remote state in S3 with DynamoDB locking.

SSH open to 0.0.0.0/0 — acceptable for a lab. Production fix is IP restriction or AWS Systems Manager Session Manager with no open port 22.

Jenkins with Docker socket access — necessary for pipeline builds in this setup. Production fix is a dedicated build agent with scoped permissions.
