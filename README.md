## Definition of Done (per phase)

### Phase 0 — Lab foundation
- Repo has first commit and clean git status
- `notes/decisions.md` explains environment choice and tradeoffs
- `notes/verification.md` captures tool versions and sanity checks

### Phase 1 — App + reverse proxy (nginx)
- `docker compose ps` shows `nginx` and `app` as **Up**
- `nginx` publishes `0.0.0.0:80->80/tcp`
- `app` has **no host port mapping** (shows `5678/tcp` only)
- `curl -i http://localhost` returns:
  - `HTTP/1.1 200 OK`
  - header `Server: nginx`
  - body contains `Hello World!`

### Phase 2 — Monitoring
- Prometheus can scrape targets and shows them as `UP`
- Grafana can load and display at least one dashboard with live metrics

### Phase 3 — Alerting
- When the app is stopped, an alert fires within a defined time window
- Alert is delivered to a notification channel (start with Slack/email)

### Phase 4 — Incident workflow
- “App down” creates an incident record (even if manual at first)
- Runbook exists with commands to verify and restore service

### Phase 5 — Documentation quality gate
## Current Architecture (Phase 1)

Traffic flow:

Client (host) → nginx (port 80) → app (internal Docker network, port 5678)

- Only **nginx** is exposed to the host on port **80**.
- The **app** is **not exposed** to the host (no published ports). It is reachable only inside the Compose network.
- nginx proxies all `/` requests to `http://app:5678`.

## How to run (Phase 1)

Start:
- `docker compose up -d`

Verify:
- `curl -i http://localhost` returns `200 OK` and the body `Hello World!`

Stop:
- `docker compose down`
