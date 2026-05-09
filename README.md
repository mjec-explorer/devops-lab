# DevOps Lab: Production-Grade AWS Infrastructure with Automated Remediation

An end-to-end DevOps platform built on AWS, provisioned entirely with Terraform, with a full CI/CD pipeline, observability stack, and intelligent alert automationbuilt from scratch.

Every resource was written, reviewed, broken, debugged, and rebuilt to understand the full lifecycle from infrastructure to incident response.

---

## Architecture

```
                        Internet
                            │
                    Internet Gateway
                            │
              ┌─────────────────────────────┐
              │         VPC 10.0.0.0/16     │
              │      eu-central-1 Frankfurt │
              │                             │
              │  ┌──── Public Subnets ────┐ │
              │  │  ALB    NAT Gateway    │ │
              │  └────────────────────────┘ │
              │             │               │
              │  ┌──── Private Subnets ───┐ │
              │  │                        │ │
              │  │  ECS Fargate (FastAPI) │ │
              │  │  Jenkins EC2           │ │
              │  │  Monitoring EC2        │ │
              │  │                        │ │
              │  └────────────────────────┘ │
              └─────────────────────────────┘
                            │
              ┌─────────────────────────────┐
              │   AWS Managed Services      │
              │   ECR  S3  SSM  CloudWatch  │
              └─────────────────────────────┘
```

---

## Stack

| Layer | Component | Purpose |
|---|---|---|
| Infrastructure | Terraform | Provisions all AWS resources |
| Network | VPC, ALB, NAT Gateway | Isolation, routing, load balancing |
| Compute | ECS Fargate, EC2 | Application and tooling |
| Registry | Amazon ECR | Container image storage |
| CI/CD | Jenkins | Build, test, push, deploy |
| Application | FastAPI | Exposes /health and /metrics |
| Monitoring | Prometheus + Grafana | Metrics collection and dashboards |
| Alerting | Alertmanager | Alert routing and deduplication |
| Automation | n8n | Alert enrichment and auto-remediation |
| Probing | Blackbox Exporter | External HTTP endpoint checks |
| Access | AWS SSM Session Manager | Zero-inbound-port EC2 access |
| State | S3 + DynamoDB | Remote Terraform state and locking |

---

## Key Architectural Decisions

**Private subnets for all workloads**
ECS tasks, Jenkins, and Monitoring EC2 all run in private subnets with no public IPs. The only way into the application is through the ALB. Attack surface is minimal even if a private IP is discovered, there is no route in from the internet.

**SSM Session Manager replaces SSH**
Jenkins and Monitoring EC2 have zero inbound security group rules. Access is through AWS Systems Manager Session Manager; IAM-controlled, no open ports, every session logged to CloudWatch. Static SSH keys are eliminated entirely.

**Immutable ECR image tags**
Every image is tagged with the Git commit SHA. Tags cannot be overwritten. If a deployment causes an incident, the exact commit is traceable in seconds. Rolling back means deploying the previous SHA.

**Separate IAM roles per service**
Four distinct IAM roles: ECS execution (AWS sets up containers), ECS task (application runtime calls), Jenkins (CI/CD operations), Monitoring (read-only metrics access). Each scoped to specific resource ARNs. Blast radius is contained if any role is compromised.

**Remote Terraform state**
State stored in S3 with versioning and AES-256 encryption. DynamoDB prevents concurrent applies. State is recoverable from previous versions if corrupted. Never stored locally or committed to git.

**Configs delivered via S3**
Monitoring configs (Prometheus, Grafana, Alertmanager, n8n) are versioned in git, uploaded to a dedicated S3 bucket, and pulled by the monitoring EC2 on first boot. Infrastructure is fully reproducible from a single `terraform apply`.

**Multi-AZ deployment**
Public and private subnets span two Availability Zones. If one AZ fails, the ALB routes to the remaining healthy AZ. ECS tasks can be distributed across both AZs for full redundancy.

---

## Infrastructure as Code

Built with Terraform, split into 11 files by responsibility:

```
terraform/
├── provider.tf          AWS provider and version constraints
├── backend.tf           S3 remote state + DynamoDB locking
├── variables.tf         All input variables with descriptions
├── networking.tf        VPC, subnets, IGW, NAT Gateway, route tables
├── security_groups.tf   ALB, ECS, Jenkins, Monitoring SGs
├── iam.tf               IAM roles, policies, instance profiles
├── ecr.tf               Container registry with lifecycle policy
├── compute.tf           Jenkins and Monitoring EC2 instances
├── alb.tf               Load balancer, target group, listener
├── ecs.tf               Cluster, task definition, service
├── s3.tf                Configs bucket
└── outputs.tf           ALB DNS, ECR URL, instance IDs
```

---

## CI/CD Pipeline

Jenkins runs on EC2 in a private subnet. Accessed via SSM port forwarding with no open ports, no public IP.

Pipeline stages:

```
1. Checkout         Pull source code from GitHub
2. Unit Tests       Build test image, run pytest (optional)
3. Build Image      Multi-stage Docker build
4. Push to ECR      Tag with Git SHA, push to ECR
5. Deploy to ECS    Register new task definition, update service
6. Wait for stable  Poll ECS until deployment completes
7. Health check     Verify /health endpoint via ALB
```

Jenkins uses the EC2 IAM instance profile with no static AWS credentials stored anywhere.

---

## Observability Stack

Runs on a dedicated EC2 in a private subnet. Accessed via SSM port forwarding.

**Prometheus** scrapes ECS tasks via AWS service discovery and automatically finds new tasks when they start or are replaced. No manual target configuration needed.

**Grafana** visualises request rate, error rate, P95 latency, and infrastructure metrics.

**Alertmanager** routes alerts through n8n for auto-remediation before escalating to Slack directly.

**n8n** enriches alerts, attempts container restart via Docker API, verifies recovery, and escalates if recovery fails.

**Blackbox Exporter** probes HTTP endpoints externally and catches scenarios where a service is running but not responding.

---

## Alert Rules

| Alert | Condition | Severity |
|---|---|---|
| InstanceWarning | Service unreachable 2 minutes | Warning |
| InstanceDown | Service unreachable 5 minutes | Critical |
| HighErrorRate | Error rate > 5% for 5 minutes | Critical |
| NoTraffic | No requests for 5 minutes | Warning |
| N8NDown | n8n endpoint unreachable 1 minute | Critical |

---

## Accessing the Infrastructure

**Jenkins UI (via SSM port forward):**
```bash
aws ssm start-session \
  --target <jenkins-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
# Open http://localhost:8080
```

**Grafana (via SSM port forward):**
```bash
aws ssm start-session \
  --target <monitoring-instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'
# Open http://localhost:3000
```

---

## Deploying

**Prerequisites:**
- AWS CLI configured with appropriate IAM permissions
- Terraform >= 1.5.0
- Docker

**Bootstrap state storage (once):**
```bash
aws s3api create-bucket \
  --bucket mjcastro-devopslab-tfstate \
  --region eu-central-1 \
  --create-bucket-configuration LocationConstraint=eu-central-1

aws s3api put-bucket-versioning \
  --bucket mjcastro-devopslab-tfstate \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

**Deploy infrastructure:**
```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Upload monitoring configs:**
```bash
aws s3 sync monitoring/ s3://devopslab-configs-439475769023/monitoring/ \
  --exclude "secrets/*"
```

**Destroy when done:**
```bash
terraform destroy
```

---

## Security Improvements From v1

| Area | Before | After |
|---|---|---|
| Network | ECS in public subnets, public IPs | ECS in private subnets, no public IPs |
| Access | SSH port 22 open, static key pairs | SSM Session Manager, zero inbound ports |
| IAM | Broad permissions, shared roles | 4 scoped roles, ARN-specific policies |
| Images | Mutable tags, no scanning | Immutable SHA tags, CVE scanning on push |
| State | Local state file | S3 + DynamoDB, encrypted, versioned |
| Configs | On dev machine only | S3 + git, reproducible on any deploy |
| Workflow | Direct pushes to main | Feature branches, documented PRs |

---

## Trade-offs

**Single NAT Gateway** — Single point of failure for outbound private subnet traffic. Production would use one NAT Gateway per AZ.

**HTTP only** — no HTTPS listener. Requires a domain name for ACM certificate. Production would add port 443 with ACM and redirect 80 → 443.

**Jenkins on t3.micro** — undersized for concurrent builds. Production would use t3.small minimum or migrate to GitHub Actions.

**desired_count = 1** — no ECS task redundancy. Production would run minimum 2 tasks across both AZs.

---

## Roadmap
- **Phase 1** — CI/CD Pipeline 
          ✅ Complete
          Jenkins, Docker, GitHub, SHA tagging, health check gate
- **Phase 2** — Observability and Incident Automation 
          ✅ Complete
          Prometheus, Grafana, Alertmanager, n8n, Blackbox,
          auto-remediation, fallback delivery
- **Phase 3** — AWS Infrastructure with Terraform 
          ✅ Complete
          VPC, ECS Fargate, ALB, ECR, SSM, IAM, S3, Multi-AZ
- **Phase 4** — Kubernetes on EKS (planned)
- **Phase 5** — Ansible for configuration management (planned)
- **Phase 6** — HTTPS with ACM, custom domain (planned)
- **Phase 7** — Security hardening, Secrets Manager (planned)

---

## Repository Structure

```
devops-lab/
├── app/                    FastAPI application and Dockerfile
├── monitoring/             Prometheus, Grafana, Alertmanager, n8n configs
├── terraform/              All infrastructure as code (11 .tf files)
├── jenkins/                Jenkins configuration
├── docker-compose.yml      Local development stack
├── Jenkinsfile             CI/CD pipeline definition
└── README.md               This file
```

---

Portfolio: https://mjec-explorer.github.io
LinkedIn: https://linkedin.com/in/mjcastro-itops
GitHub: https://github.com/mjec-explorer/devops-lab
