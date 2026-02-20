## Definition of Done (per phase)

### Phase 0 — Lab foundation
- Repo has first commit and clean git status
- `notes/decisions.md` explains environment choice and tradeoffs
- `notes/verification.md` captures tool versions and sanity checks

### Phase 1 — App + reverse proxy + health
- Reverse proxy responds `200 OK` on `/`
- App responds `200 OK` on `/health` with JSON `{ "status": "ok" }`
- Restarting the stack works consistently after stopping everything

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
