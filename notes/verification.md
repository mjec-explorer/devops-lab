# Verification (Phase 0)

## Tool versions
- git: 2.34.1
- docker: 28.2.2
- docker compose: 2.39.1-desktop.1

## Quick checks performed
- Git: repo initialized and first commit created
- Docker: can run a container and remove it
- Compose: can parse docker-compose.yml without YAML errors
- HTTP client: curl can fetch a public webpage


## Phase 1 verification (App + nginx reverse proxy)

Expected running services:
- app (internal only): container port `5678/tcp` (no host port)
- nginx (public entrypoint): host port `80:80`

Observed results:
- `docker compose ps` shows both services **Up**
- `curl -i http://localhost` returns `HTTP/1.1 200 OK`
- Response includes `Server: nginx` and body `Hello World!`
- App is reachable through nginx via `proxy_pass http://app:5678`

