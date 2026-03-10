from fastapi import FastAPI, Request
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
import time

app = FastAPI(title="devops_lab_app")

REQUESTS = Counter(
         "app_requests_total", 
         "Total HTTP requests", 
         ["path", "status_code"]
)

REQUEST_DURATION = Histogram(
         "app_request_duration_seconds",
         "HTTP request duration in seconds",
         ["path"],
         buckets=[0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0]
)

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.time()

    response = await call_next(request)

    duration = time.time() - start
    path = request.url.path
    status = str(response.status_code)

    # Skip recording metrics for the /metrics endpoint itself
    # (otherwise you get noise from Prometheus scraping)
    if path != "/metrics":
        REQUESTS.labels(path=path, status_code=status).inc()
        REQUEST_DURATION.labels(path=path).observe(duration)

    return response

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "Hello from devops_lab_app!"}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
