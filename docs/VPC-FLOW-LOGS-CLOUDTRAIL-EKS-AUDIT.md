# VPC Flow Logs, CloudTrail, and EKS Audit Logging (TITANOPS-122)

## Overview & Background
Prior to **TITANOPS-122**, the infrastructure lacked persistent network flow tracking, AWS API management event audit trails, and Kubernetes control plane operational telemetry. Under this ticket, comprehensive defense-in-depth observability and security auditing are provisioned via Terraform across the network, cloud management plane, and container orchestration layers.

---

## Architectural Implementation

### 1. VPC Flow Logs
- **Scope**: Monitors all ingress and egress network interfaces (`traffic_type = "ALL"`) across private and public subnets.
- **Log Destination**: Shipped directly to a dedicated Amazon CloudWatch Log Group (`/aws/vpc/titanops-dev-flow-logs`) with configurable retention (30 days).
- **Security Context**: Uses an IAM service role (`vpc-flow-logs.amazonaws.com`) with least-privilege permissions constrained strictly to `logs:CreateLogStream` and `logs:PutLogEvents`.

### 2. AWS CloudTrail Audit Trail
- **Management & Security Auditing**: Tracks all AWS API calls, user logins, and infrastructure mutations across the entire environment.
- **Multi-Region & Global Services**: Enables `is_multi_region_trail = true` and `include_global_service_events = true` to capture global IAM modifications.
- **Dual Destination Architecture**:
  - **Cold Archive**: Shipped to an encrypted, versioned, private S3 bucket (`aws_s3_bucket.cloudtrail`) with public access fully blocked.
  - **Hot Stream**: Forwarded to Amazon CloudWatch Logs (`/aws/cloudtrail/titanops-dev-audit-trail`) for real-time alerting and SIEM ingestion.

### 3. EKS Control Plane Logging
The EKS cluster (`aws_eks_cluster.this`) enables the complete suite of Kubernetes control plane logs:
- `api`: Kubernetes API server transactions and request payloads.
- `audit`: Cluster audit log records detailing user, pod, and service account actions.
- `authenticator`: EKS IAM authenticator RBAC mapping evaluations.
- `controllerManager`: Core Kubernetes controller events (deployments, replica sets).
- `scheduler`: Pod placement decisions and scheduling constraints.

---

## Automated Verification
Executed via `scripts/test-vpc-flow-cloudtrail-eks-audit.sh`:
- Validation of VPC Flow Log resource definition, CloudWatch delivery, and IAM roles.
- CloudTrail multi-region configuration, S3 bucket encryption/versioning/public block, and CloudWatch streaming.
- EKS cluster `enabled_cluster_log_types` configuration.
- Terraform root output availability.
