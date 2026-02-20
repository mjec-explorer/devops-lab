# DevOps Lab — From Scratch Infrastructure

This repository documents a phased DevOps infrastructure project built from scratch using containerized services.

## Goals

- Practice production-style service architecture
- Implement reverse proxy, monitoring, alerting, and incident workflows
- Build everything reproducibly using Docker Compose
- Document each phase as an infra portfolio artifact

---

## Current Architecture (Phase 1)

Traffic flow:

Client (host)
   ↓
nginx (port 80 exposed)
   ↓
app (internal Docker network, port 5678)

### Design Summary

- nginx acts as the public gateway (port 80 exposed)
- Backend services remain internal
- Traffic is routed via Docker DNS (`app:5678`)

---

## Repository Structure
devops_lab/
├── docker-compose.yml
├── nginx/
│ └── default.conf
├── notes/
│ ├── decisions.md
│ └── verification.md
└── README.md

## How to Run (Phase 1)

Start the stack:
 `docker compose up -d`

Verify services:
 `docker compose ps`
 `curl -i http://localhost`

Expected Results:
- nginx → Up → `0.0.0.0:80->80/tcp`
- app → Up → `5678/tcp` only
- Curl returns `Hello World!`

Stop service:
 `docker compose down`

## Definition of Done

### Phase 0 — Lab Foundation

- Git repo initialized
- Clean commit history
- Environment documented
- Docker + Compose verified

### Phase 1 — App + Reverse Proxy

- nginx proxies traffic to internal app
- app not publicly exposed
- curl via localhost returns app response
- Direct access to app host port fails

### Phase 2 — Monitoring

- Prometheus scrapes targets
- Grafana dashboard shows metrics

### Phase 3 — Alerting

- App stop triggers alert
- Notification delivered

### Phase 4 — Incident Workflow

- Runbook exists
- Recovery steps documented

### Phase 5 — Documentation Quality Gate

- Stack reproducible from repo only
- No undocumented manual steps

---

## Networking Model

Public:

Host → nginx:80

Internal:

nginx → app:5678

---

## Next Phases

- Monitoring stack
- Observability dashboards
- Alert routing
- Incident simulations

