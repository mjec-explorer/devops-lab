# DevOps Lab: Building a CI/CD + Monitoring Stack 
## Overview

This repository documents a personal DevOps lab where I built a small production-style infrastructure from the ground up.

Instead of studying the tools individually, the goal of this project is to understand how the pieces of a real deployment workflow connect together from building an application image, running automated tests, publishing it to a registry, deploying it, and monitoring its health.

Everything in this repository is intentionally designed so it can be **rebuilt from scratch**, which is the best way to deeply understand infrastructure.

The stack currently includes:

* FastAPI application
* Nginx reverse proxy
* Jenkins CI/CD pipeline
* Docker multi-stage builds
* GitHub Container Registry (GHCR)
* Prometheus monitoring
* Node Exporter host metrics
* Grafana dashboards
* Alertmanager → Slack notifications

This project serves both as a **learning lab and a DevOps portfolio artifact**.

---

# Architecture Overview
![DevOps Workflow Diagram](https://github.com/mjec-explorer/devops-lab/blob/main/notes/devops-lab-workflow.png)
### Runtime traffic flow

Client request --> Nginx (public entrypoint on port 80) --> FastAPI application container

Monitoring flow:
Prometheus scrapes metrics from:
   * FastAPI `/metrics`
   * Node Exporter `/metrics`

Alert flow:
Prometheus --> Alertmanager --> Slack notification

Visualization:
Grafana dashboards query Prometheus for metrics.

---

# CI/CD Pipeline Flow

The CI/CD pipeline is handled by Jenkins and runs the following stages:

1. **Checkout source code** from GitHub
2. **Run unit tests** using a Docker test stage
3. **Build the runtime image**
4. **Tag the image using the Git commit SHA**
5. **Push the image to GitHub Container Registry**
6. **Deploy the new version using Docker Compose**
7. **Validate container health**
8. **Verify the application endpoint**

The deployment only succeeds if the container passes the health check.

---

# Repository Structure

```
mjcastro@MJeC:~/devops_lab$ tree
.
├── Jenkinsfile                   # CI/CD Pipeline definition
├── README.md                     # Project documentation
├── alertmanager                  # Alert routing & notification logic
│   └── alertmanager.yml          
├── app                           # FastAPI Source code & Unit tests
│   ├── Dockerfile                # Multi-stage build (test -> production)
│   ├── __init__.py
│   ├── main.py
│   ├── requirements.txt
│   └── tests
│       └── test_health.py
├── docker-compose.cicd.yml       # Auxiliary stack (Jenkins)
├── docker-compose.yml            # Main runtime stack (App, Nginx, Monitoring)
├── jenkins                       # Custom Jenkins image with Docker-out-of-Docker
│   └── Dockerfile
├── nginx                         # Reverse proxy & Load balancing config
│   └── default.conf
├── notes                         # Architectural decisions & logs
│   ├── decisions.md
│   └── verification.md
├── prometheus                    # Metrics collection & Alerting rules
│   ├── alerts.yml
│   └── prometheus.yml
└── secrets                       # Local sensitive data (GIT-IGNORED)
    └── slack_webhook.txt


    
```
---

# Running the Stack Locally

Start the runtime stack:

```
docker compose up -d
```

Check running containers:

```
docker compose ps
```

Test the application:

```
curl http://localhost/health
```

Expected response:

```
{"status":"ok"}
```

---

# Running Jenkins CI/CD

Start Jenkins:

```
docker compose -f docker-compose.yml -f docker-compose.cicd.yml up -d --build jenkins
```

Open Jenkins:

```
http://localhost:8080
```
When Jenkins starts for the first time, it requires the Initial Admin Password.

Retrieve it with:
```
docker exec devops_lab-jenkins-1 cat /var/jenkins_home/secrets/initialAdminPassword
```
Use the password to unlock Jenkins and complete the setup.

Run the pipeline:

```
devops-lab-ci
```

Pipeline stages:

* Checkout
* Unit Tests
* Build Image
* Push Image
* Deploy
* Health Validation

---

# Monitoring and Observability

Prometheus collects metrics from:

* FastAPI application metrics endpoint
* Node Exporter for host system metrics

Alertmanager routes alerts to Slack when issues occur.

Grafana is used to visualize metrics through dashboards.

---
For this lab environment, Jenkins is allowed to access the Docker daemon directly by mounting the Docker socket:
```
/var/run/docker.sock
```
This allows Jenkins pipelines to build and deploy containers directly on the host to keep the setup simple and reproducible locally.

---
# Current Status

So far the following parts are implemented:

* Dockerized application
* Reverse proxy routing with Nginx
* Multi-stage Docker builds
* Jenkins CI pipeline
* Image publishing to GHCR
* Automated deployment using Docker Compose
* Health-checked deployments
* Monitoring with Prometheus
* Infrastructure metrics via Node Exporter
* Slack alert notifications

---

# Next Improvements

The current setup is intentionally simple so it is easy to understand and reproduce.

Planned improvements include:

Deployment improvements

* Automatic rollback when a deployment fails
* Blue/Green deployment approach
* Deployment timeout protection

CI/CD improvements

* GitHub webhook triggers
* Branch-based deployment rules
* Build caching improvements

Security improvements

* Run Jenkins with restricted permissions
* Improve secrets management
* Remove direct Docker socket access

Observability improvements

* Add application-level metrics
* Improve alert rules
* Create additional Grafana dashboards

Testing improvements

* Add load testing stage
* Simulate real failure scenarios

---

# Learning Objective

The main purpose of this lab is not just to make it work once, but to be confident enough to recreate the entire stack again from scratch.

Each phase focuses on understanding:

* how CI/CD pipelines actually deploy code
* how containers communicate inside networks
* how monitoring tools collect metrics
* how alerts are triggered during failures
* how to troubleshoot infrastructure problems

The goal is not just to make it work once, but to be confident enough to recreate the entire stack again from scratch.

## Documentation & Architecture Decisions

For a deeper dive into how this system was built and how to verify its state, please refer to the following:

* [**Architecture Decisions**](./notes/decisions.md): Why I chose this specific stack, the split Docker Compose strategy, and security trade-offs.
* [**System Verification**](./notes/verification.md): A step-by-step guide to testing that the monitoring, alerts, and CI/CD pipeline are functioning correctly.
