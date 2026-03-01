FROM python:3.12-slim AS base
WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

FROM base AS test
ENV PYTHONPATH=/app
RUN pytest -q

FROM base AS runtime
EXPOSE 8000
