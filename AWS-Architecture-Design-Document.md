# MediCore HMS — AWS Architecture Design Document

| | |
|---|---|
| **Project** | Capstone: End-to-End DevOps Pipeline for Application with CI/CD |
| **Application** | MediCore HMS (Hospital Management System) |
| **Target platform** | Amazon EKS, AWS ap-south-1 (Mumbai) |
| **Diagram reference** | `hms-aws-architecture-v5.drawio` — "Main Architecture" page (this document) and "Edge Security & Logging" page (CDN/WAF/logging detail) |
| **Status** | Target-state design |

---

## Architecture Diagram

![MediCore HMS AWS Architecture](Diagrams/hms-aws-architecture-v5-Main%20Architecture.drawio.png)

*Main Architecture page — see `hms-aws-architecture-v5.drawio` for the full interactive diagram, including the separate "Edge Security & Logging" detail page.*

---

## 1. Purpose and Scope

This document describes the target-state AWS architecture for hosting MediCore HMS — a Java Spring Boot microservices backend (9 services) with a React frontend — on Amazon EKS, including networking, compute, data, edge/CDN, security, observability, and the CI/CD pipeline that provisions and deploys it.

It accompanies the architecture diagram and is intended to give reviewers (client, evaluators, and the engineering team) a single narrative reference for *why* each component is there, not just *what* it is.

Out of scope: application-level design (see `HIGH-LEVEL-DESIGN.md` / `LOW-LEVEL-DESIGN.md` in the `hms-core` repo) and the detailed WAF rule-group / access-logging breakdown, which lives on the diagram's separate "Edge Security & Logging" page.

---

## 2. Architecture at a Glance

```
End Users → Route 53 → CloudFront (+ WAF) → ALB → EKS (9 microservices + frontend) → RDS MySQL (Multi-AZ)
                              │
                              └→ S3 (static frontend assets, cached at edge)

CI/CD:  Developer → GitHub → GitHub Actions → ECR (images) + Terraform (infra) → EKS (Helm deploy, via IRSA)
```

The design targets a single AWS region (ap-south-1) spread across two Availability Zones for high availability, with a clear separation between the **edge/CDN tier**, the **application tier** (EKS on private subnets), the **data tier** (RDS on private subnets, no direct internet route), and a **CI/CD tier** that provisions and deploys everything via GitHub Actions, Terraform, and Helm.

---

## 3. Key Design Decisions

A few decisions are worth calling out explicitly, since they're not obvious from the diagram alone:

- **Single ALB endpoint, multi-AZ presence.** The Application Load Balancer exposes exactly one stable DNS name (`hms-alb-xxxxxxxx.ap-south-1.elb.amazonaws.com`). AWS transparently places one Elastic Network Interface for that same ALB in each AZ's public subnet — this is *how* the ALB achieves high availability, not two separate load balancers. Clients only ever resolve and connect to the single name; Route 53 and CloudFront both point at it once.
- **CloudFront in front of the ALB, not instead of it.** Static frontend assets (the React SPA) are served from S3 and cached at CloudFront's edge; only dynamic `/api/*` traffic is forwarded to the ALB. This keeps latency low for the SPA shell without adding a caching layer in front of stateful API calls.
- **AWS WAF attached to CloudFront's Web ACL**, not inserted as an inline network hop — this is how WAF actually works (a Web ACL association, evaluated at the edge before CloudFront serves or forwards a request), and keeps the data-flow diagram honest about where filtering happens.
- **EKS managed node groups inside an Auto Scaling Group**, one per AZ, rather than bare EC2 instances — gives us rolling node replacement and scale-out without hand-rolled automation.
- **RDS MySQL Multi-AZ with a single write endpoint.** The application only ever talks to the primary; the standby receives synchronous replication and is promoted automatically on failover. The diagram deliberately shows one JDBC path (app → primary) and a separate replication-only path (primary → standby) rather than implying the app talks to both.
- **No bastion host.** Operational access to worker nodes goes through AWS Systems Manager Session Manager — no inbound SSH port, no SSH key management, and every session is logged in CloudTrail.
- **OIDC federation instead of long-lived AWS keys.** GitHub Actions assumes an IAM role via OpenID Connect for every AWS-facing step (Terraform, ECR push, Helm deploy) — there are no static AWS access keys stored anywhere in GitHub Secrets.
- **Terraform remote state in S3**, separate from the application's own S3 buckets (frontend assets, access logs), so infra state, static assets, and logs each have their own lifecycle and access policy.

---

## 4. Component Breakdown

### 4.1 Edge & Content Delivery

| Component | Role |
|---|---|
| **Route 53** | Public DNS; resolves the application's hostname to CloudFront. |
| **CloudFront** | CDN in front of both the static frontend and the API. Serves cached SPA assets from S3; forwards `/api/*` to the ALB. Web ACL (WAF) is attached here. |
| **AWS WAF** | Edge protection via AWS Managed Rule Groups (Core rule set, known bad inputs, SQLi, IP reputation, rate-based rule). Full rule breakdown is on the diagram's "Edge Security & Logging" page. |
| **ACM** | Public TLS certificates, used by both CloudFront (edge TLS) and the ALB (regional TLS to origin). |
| **S3 (Frontend SPA Assets)** | Origin bucket for the built React app; not directly internet-facing — only CloudFront reads from it. |

### 4.2 Networking

| Component | Role |
|---|---|
| **VPC** | `10.0.0.0/16`, spanning two Availability Zones. |
| **Internet Gateway** | Provides the VPC's only route to/from the public internet, used by the ALB and by NAT Gateways for outbound traffic. |
| **NAT Gateway (×2, one per AZ)** | Outbound-only internet access for private subnets (dependency downloads, AWS API calls that aren't via VPC endpoints, etc.). One per AZ avoids a cross-AZ single point of failure. |
| **Application Load Balancer** | Single logical load balancer, one DNS name, ENIs in both AZs' public subnets. Routes `/api/*` traffic from CloudFront to EKS pods. |

**Subnet layout:**

| Subnet | CIDR | AZ | Purpose |
|---|---|---|---|
| Public Subnet A | `10.0.1.0/24` | A | ALB ENI, NAT Gateway A |
| Public Subnet B | `10.0.2.0/24` | B | ALB ENI, NAT Gateway B |
| Private App Subnet A | `10.0.11.0/24` | A | EKS worker nodes (Auto Scaling Group) |
| Private App Subnet B | `10.0.12.0/24` | B | EKS worker nodes (Auto Scaling Group) |
| Private DB Subnet A | `10.0.21.0/24` | A | RDS primary |
| Private DB Subnet B | `10.0.22.0/24` | B | RDS standby |

### 4.3 Compute & Container Orchestration

| Component | Role |
|---|---|
| **Amazon EKS Control Plane** | Managed Kubernetes control plane; AWS-operated, spans both AZs. |
| **Auto Scaling Group (EKS Managed Node Group) × 2** | One ASG per AZ, currently running `m5.large` EC2 worker nodes; scales the node count based on pod scheduling pressure. |
| **Workloads (Helm, 2 replicas each)** | 9 Spring Boot microservices — patient, appointment, user, billing, encounter, lab, medication, prescription, provider — plus the React/nginx frontend. Every service runs 2 replicas spread across both AZs for availability during node or AZ-level disruption. |

### 4.4 Data Layer

| Component | Role |
|---|---|
| **RDS MySQL 8.0, Multi-AZ (Primary)** | The application's only write/read target, reached over JDBC on port 3306 from the app subnet in AZ-A. |
| **RDS MySQL 8.0, Multi-AZ (Standby)** | Synchronous replica in AZ-B; promoted automatically by RDS on primary failure. The application never connects to it directly. |

### 4.5 Security & Identity

| Component | Role |
|---|---|
| **IAM (OIDC Provider + IRSA)** | Two related but distinct trust relationships: (1) GitHub Actions assumes an IAM role via OIDC for CI/CD, no static keys; (2) in-cluster pods assume scoped IAM roles via IRSA (IAM Roles for Service Accounts) rather than sharing the node's instance role. |
| **Secrets Manager** | Stores application secrets (DB credentials, API keys); consumed in-cluster via the External Secrets Operator rather than baked into manifests or images. |
| **GuardDuty** | Continuously analyzes VPC Flow Logs, CloudTrail, and EKS audit logs for threat detection. |
| **Security Hub** | Aggregates findings (including GuardDuty's) into a single security posture view. |
| **AWS WAF** | See §4.1 — Managed Rule Groups at the edge. |
| **AWS Systems Manager Session Manager** | Operational access to worker nodes with no bastion host and no SSH keys; every session is auditable. |

### 4.6 Observability & Monitoring

| Component | Role |
|---|---|
| **Prometheus + Grafana** | Self-hosted in-cluster via Helm; scrapes `/actuator/prometheus` on every pod. Primary tool for application and cluster performance dashboards. |
| **CloudWatch** | Receives VPC Flow Logs and EKS Container Insights (logs/metrics) for infrastructure-level visibility alongside Prometheus/Grafana. |
| **VPC Flow Logs** | Network-level audit trail, feeding both CloudWatch and GuardDuty. |

### 4.7 CI/CD-Facing Regional Services

| Component | Role |
|---|---|
| **ECR (10 repositories)** | One repository per deployable artifact — the 9 microservices plus the frontend image. |
| **S3 (Terraform State)** | Remote state backend with locking, enabling consistent, team-safe `terraform apply` runs — kept separate from the frontend-assets and access-log buckets. |

---

## 5. CI/CD Pipeline (External to AWS)

| Component | Role |
|---|---|
| **Developer** | Pushes code to the `hms-core` GitHub repository. |
| **GitHub Repository (hms-core)** | Source of truth; triggers GitHub Actions on push/PR. |
| **GitHub Actions CI/CD Pipeline** | Builds and pushes Docker images to ECR, assumes an AWS IAM role via OIDC, runs `terraform plan`/`apply`, and deploys to EKS via Helm using IRSA-scoped credentials. |
| **Terraform (Infrastructure as Code)** | Provisions VPC, subnets, EKS, RDS, and ECR; state stored remotely in S3 with locking. |

---

## 6. Request and Deployment Flow

1. **DNS resolution** — client resolves the application hostname via Route 53.
2. **Edge** — CloudFront receives the request; the attached WAF Web ACL evaluates it against the managed rule groups before anything is served or forwarded.
3. **Content split** — static assets are served from the S3-backed CloudFront cache; any `/api/*` request is forwarded to the ALB.
4. **Load balancing** — the ALB (single DNS name, ENI in each AZ) routes the request to a healthy pod in either AZ.
5. **Data access** — the receiving microservice reads/writes RDS MySQL via the Multi-AZ primary; the standby stays in sync via replication, never touched directly by the app.
6. **Build** — on a code push, GitHub Actions builds a Docker image and pushes it to the corresponding ECR repository.
7. **Authentication** — GitHub Actions assumes its AWS IAM role via OIDC federation for every AWS-facing step; no long-lived credentials are stored in GitHub.
8. **Provisioning** — Terraform (run from GitHub Actions) provisions or updates AWS infrastructure, with state persisted in S3.
9. **Deployment** — Helm deploys the new image to EKS, authenticating in-cluster via IRSA.

---

## 7. High Availability and Resilience

- **Two Availability Zones** for every tier that supports it: NAT Gateways, EKS worker nodes, application pods (2 replicas, spread across AZs), and RDS (Multi-AZ synchronous standby).
- **Single ALB endpoint** with AZ-redundant ENIs means a full AZ outage doesn't change the client-facing DNS name — traffic simply stops routing to the affected AZ's targets.
- **RDS automatic failover** to the standby on primary failure, transparent to the application beyond a brief connection interruption.
- **EKS Managed Node Groups** replace unhealthy nodes automatically and can scale out under load.

---

## 8. Security Posture Summary

- No inbound SSH anywhere in the VPC — operational access is via SSM Session Manager only.
- No long-lived AWS credentials in CI/CD — GitHub Actions authenticates via OIDC-federated, least-privilege IAM roles scoped to `repo:<org>/<repo>:ref:refs/heads/main`.
- Application secrets live in Secrets Manager, not in source control or container images, and are synced into the cluster via the External Secrets Operator.
- Edge-layer filtering (WAF managed rule groups) blocks common exploit patterns, known bad inputs, SQL injection attempts, and abusive request rates before they reach the application.
- GuardDuty and Security Hub provide continuous threat detection and a consolidated security posture view.
- The data tier (RDS) sits in private subnets with no route to the internet; it is only reachable from the application subnets.

---

## 9. Cost Optimization Notes

A detailed monthly cost estimate for this architecture (small-pilot sizing: 2 EKS worker nodes, `db.t3.medium` RDS Multi-AZ, ~50 GB/month CloudFront egress) is maintained separately in `hms-aws-cost-estimate.xlsx`, alongside a 2-hour test-run estimate. Key levers identified there, worth restating here for design review:

- A single NAT Gateway (instead of one per AZ) trades some availability for a meaningful monthly saving — kept as two in this design for HA, but flagged as a cost/availability tradeoff.
- Reserved Instances / Savings Plans for the EC2 worker nodes and RDS instance would meaningfully reduce steady-state compute cost versus the on-demand pricing used in the estimate.
- S3 Intelligent-Tiering is worth applying to the access-log and Terraform-state buckets, whose access patterns are infrequent after the first few days.

---

## 10. Assumptions

- Single AWS region (ap-south-1) and two Availability Zones; no cross-region disaster recovery in this design.
- CI/CD orchestration is GitHub Actions (per the current Jira/TITANOPS backlog), not Jenkins, despite the original capstone problem statement specifying Jenkins.
- Sizing throughout (instance types, replica counts) targets a pilot/demo-scale deployment, not modeled production traffic — see the cost estimate workbook for the explicit assumptions behind each figure.
- The WAF rule-group list, access-logging destinations, and VPC Flow Logs sink are detailed on the diagram's separate "Edge Security & Logging" page, summarized only at a high level in §4.1 and §4.6 here.

---

## 11. Diagram Legend

- **Solid lines** — live traffic / data flow
- **Dashed lines** — control-plane, CI/CD, or IAM-related flow
- **Color coding** — Compute (orange), Database (blue), Networking (purple), Security (red), Storage (green), Management (pink)

---

## 12. References

- `Diagrams/hms-aws-architecture-v5.drawio` — source architecture diagram (Main Architecture + Edge Security & Logging pages)
- `Diagrams/hms-aws-architecture-v5-Main Architecture.drawio.png` — exported PNG of the Main Architecture page, embedded above
- `hms-aws-cost-estimate.xlsx` — monthly and 2-hour cost estimates
- `titanops-hms-core` repository — application source, Dockerfiles, CI/CD workflows, and (as of this design) `infra/bootstrap-oidc/` Terraform
- TITANOPS Jira project — Sprint backlog and ticket-level implementation tracking
