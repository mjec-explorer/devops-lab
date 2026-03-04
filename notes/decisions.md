# Architecture Decisions

This document explains some of the technical choices made while building this DevOps lab.

The focus of the project is learning, so decisions were made to keep the system understandable and reproducible.

---

# CI/CD Tooling

Jenkins was selected because it is widely used and clearly demonstrates CI/CD pipelines.

Advantages:

* flexible pipeline configuration
* good Docker integration
* widely recognized in production environments

Tradeoff:

Jenkins requires additional security hardening in real production environments.

---

# Multi-Stage Docker Builds

The Dockerfile uses two stages:

1. Test stage
2. Runtime stage

Benefits:

* tests run during build
* smaller final image
* reduced attack surface

---

# Image Tagging Strategy

Images are tagged using the Git commit SHA.

Example:

```
ghcr.io/mjec-explorer/devops-lab-app:3609a1e
```

Benefits:

* traceable deployments
* deterministic rollbacks
* avoids accidental overwriting

---

# Reverse Proxy

Nginx acts as the public entrypoint for the system.

Responsibilities:

* receive traffic on port 80
* forward requests to the FastAPI service

This keeps the backend container isolated within the Docker network.

---

# Monitoring Strategy

Prometheus uses a pull model.

It scrapes metrics from:

* FastAPI `/metrics`
* Node Exporter `/metrics`

Node Exporter provides host-level metrics such as CPU, memory, and disk usage.

---

# Alerting

Prometheus alert rules trigger Alertmanager.

Alertmanager then routes notifications to Slack.

This separation allows alerts to be routed to multiple destinations if needed.

---

# Known Limitations

Current design intentionally keeps things simple.

Limitations include:

* no automated rollback yet
* Jenkins running with Docker socket access
* limited application metrics
* basic dashboards

These are planned improvements for the next phase.
