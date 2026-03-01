from fastapi import FastAPI
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

app = FastAPI(title="devops_lab_app")

REQUESTS = Counter("app_requests_total", "Total HTTP requests", ["path"])

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    REQUESTS.labels(path="/").inc()
    return {"message": "hello from devops_lab_app"}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
