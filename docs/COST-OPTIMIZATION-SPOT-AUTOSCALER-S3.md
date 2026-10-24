# Cost Optimization Runbook: Spot Node Groups, Cluster Autoscaler & S3 Lifecycle Rules

**Jira Ticket:** TITANOPS-123  
**Status:** In Review  
**Assignee:** Kaushal Patil (@kaushalpatil205)  
**Reviewer:** @Rxborole  

---

## 1. Executive Summary & Objectives

Cloud infrastructure costs in containerized enterprise environments are dominated by compute (EC2 worker nodes) and long-term object storage (state files, access logs, audit trails). Without active cost governance, clusters accumulate idle compute capacity and noncurrent storage versions indefinitely.

This implementation satisfies all three criteria of the **TITANOPS-123** Definition of Done (DoD):
1. **Spot Node Groups:** Configured a dedicated EKS Managed Node Group with `capacity_type = "SPOT"` alongside our baseline On-Demand node group, achieving **70% to 90% compute cost savings** for stateless and burstable workloads.
2. **Cluster Autoscaler & IRSA:** Deployed Kubernetes Cluster Autoscaler with least-privilege IAM Roles for Service Accounts (IRSA), dynamically scaling worker node counts up or down based on pod resource demand.
3. **S3 Tiered Lifecycle Rules:** Configured automated transition rules (`Standard` &rarr; `Standard-IA` &rarr; `Glacier` &rarr; `Expiration`) and incomplete multipart upload cleanup on both the Terraform remote state bucket and the access/audit log bucket.

---

## 2. Architecture Overview

### 2.1 Mixed Spot/On-Demand Node Group Topology

```
+-----------------------------------------------------------------------------------+
|                                 Amazon EKS Cluster                                |
|                                                                                   |
|  +-------------------------------------+   +------------------------------------+  |
|  |     On-Demand Node Group (m5.large) |   |    Spot Node Group (Multi-Instance)|  |
|  |     Desired: 2 | Min: 2 | Max: 4    |   |    Desired: 2 | Min: 1 | Max: 8    |  |
|  |                                     |   |    Types: t3.large, t3a.large,     |  |
|  |  Workloads:                         |   |           m5.large, m5a.large      |  |
|  |  - CoreDNS, kube-system pods        |   |                                    |  |
|  |  - Stateful DB/Cache components     |   |  Workloads:                        |  |
|  |  - Cluster Autoscaler Controller    |   |  - 10 HMS Microservices            |  |
|  |                                     |   |  - Frontend Web UI                 |  |
|  |  Labels: workload=system            |   |  - Async background workers        |  |
|  |                                     |   |  Labels: capacity=spot,            |  |
|  |                                     |   |          workload=stateless        |  |
|  +-------------------------------------+   +------------------------------------+  |
+-----------------------------------------------------------------------------------+
                                         ^
                                         | Dynamic Scaling (IRSA)
                     +---------------------------------------+
                     |    Kubernetes Cluster Autoscaler      |
                     |  - Scoped to k8s.io/cluster-autoscaler|
                     |  - Expander: least-waste              |
                     +---------------------------------------+
```

### 2.2 Instance Diversification Strategy
To protect against Spot instance interruptions when AWS reclaims capacity in a specific availability zone or pool, the Spot node group specifies 4 diverse instance types:
- `t3.large` (2 vCPU, 8 GiB RAM - Intel burstable)
- `t3a.large` (2 vCPU, 8 GiB RAM - AMD burstable, ~10% cheaper)
- `m5.large` (2 vCPU, 8 GiB RAM - Intel general purpose)
- `m5a.large` (2 vCPU, 8 GiB RAM - AMD general purpose)

By spreading across two CPU vendors (Intel and AMD) and two instance families, EKS can fulfill Spot requests even when a single pool experiences high spot demand.

### 2.3 S3 Storage Lifecycle & Tiering Architecture

```
Time Horizon:
Day 0                Day 30                     Day 60                      Day 90                Day 365
  |                    |                          |                           |                     |
  +-- S3 Standard -----+-- S3 Standard-IA --------+-- S3 Glacier Flexible ---+-- Expired (State) --+-- Expired (Logs)
      ($0.023/GB/mo)       ($0.0125/GB/mo)            ($0.004/GB/mo)              (Permanent Deletion)
      Active state files   40% cost reduction         82% cost reduction          Zero ongoing cost
```

1. **Noncurrent State Versions:**
   - Day 0–30: S3 Standard
   - Day 30–60: Transitioned to `STANDARD_IA` (Standard Infrequent Access)
   - Day 60–90: Transitioned to `GLACIER`
   - Day 90: Automatically expired (`noncurrent_version_expiration`)
   - Incomplete multipart uploads: Aborted after 7 days
   - Delete markers: Automatically purged (`expired_object_delete_marker = true`)
2. **Access & Audit Logs:**
   - Day 30: Transitioned to `STANDARD_IA`
   - Day 90: Transitioned to `GLACIER`
   - Day 365: Expired and permanently purged

---

## 3. Configuration & Code Reference

### 3.1 EKS Spot Node Group (`infra/infra-stack/modules/eks/main.tf`)
```hcl
resource "aws_eks_node_group" "spot" {
  count           = var.enable_spot_node_group ? 1 : 0
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-spot-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  capacity_type   = "SPOT"
  instance_types  = var.spot_instance_types

  scaling_config {
    desired_size = var.spot_desired
    min_size     = var.spot_min
    max_size     = var.spot_max
  }

  labels = {
    "node.kubernetes.io/lifecycle" = "spot"
    "capacity"                     = "spot"
    "workload"                     = "stateless"
  }

  launch_template {
    id      = aws_launch_template.spot_node[0].id
    version = aws_launch_template.spot_node[0].latest_version
  }

  tags = merge(
    var.tags,
    {
      "k8s.io/cluster-autoscaler/enabled"               = "true"
      "k8s.io/cluster-autoscaler/${var.name}"           = "owned"
      "k8s.io/cluster-autoscaler/node-template/label/node.kubernetes.io/lifecycle" = "spot"
      "k8s.io/cluster-autoscaler/node-template/label/capacity"                     = "spot"
      "k8s.io/cluster-autoscaler/node-template/label/workload"                     = "stateless"
    }
  )

  depends_on = [aws_iam_role_policy_attachment.node]
}
```

### 3.2 S3 Lifecycle Rules (`infra/infra-stack/modules/remote-state/main.tf`)
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "cost-optimization-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_transition {
      noncurrent_days = var.transition_ia_days # 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = var.transition_glacier_days # 60
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_retention_days # 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    expired_object_delete_marker = true
  }
}
```

---

## 4. Verification Suite Results

The automated test harness `infra/test/verify-cost-optimization.sh` runs 30 distinct tests across 6 suites:
```text
========================================================================
  TITANOPS-123: Cost Optimization & Autoscaling Verification Suite      
========================================================================

--- Test Suite 1: Spot & On-Demand Node Group Architecture (DoD #1) ---
  [PASS] EKS module defines Spot launch template with IMDSv2
  [PASS] EKS node group configured with capacity_type = 'SPOT'
  [PASS] Spot node group configures multi-instance diversification
  [PASS] Spot node group labels nodes with lifecycle=spot & workload=stateless
  [PASS] On-Demand node group preserved for critical/stateful baseline
  [PASS] Node groups tagged for Cluster Autoscaler auto-discovery
  [PASS] Dev environment config.yaml enables Spot node group & autoscaling

--- Test Suite 2: Cluster Autoscaler IRSA & IAM Permissions (DoD #2) ---
  [PASS] Cluster Autoscaler IAM policy grants read discovery actions
  [PASS] Cluster Autoscaler IAM policy grants scaling mutation actions
  [PASS] Autoscaling mutation actions strictly scoped by cluster tag condition
  [PASS] IRSA trust policy scoped to kube-system:cluster-autoscaler
  [PASS] EKS module exports cluster_autoscaler_role_arn
  [PASS] hms-core-stack wires Spot node group & Autoscaler outputs

--- Test Suite 3: S3 Remote State Bucket Lifecycle Rules (DoD #3) ---
  [PASS] S3 remote state bucket has lifecycle configuration enabled
  [PASS] Noncurrent state versions transition to STANDARD_IA (30 days)
  [PASS] Noncurrent state versions transition to GLACIER (60 days)
  [PASS] Noncurrent state versions expire automatically after retention
  [PASS] Incomplete multipart uploads aborted after 7 days
  [PASS] Expired object delete markers automatically purged

--- Test Suite 4: S3 Access & Audit Logs Bucket Lifecycle Rules (DoD #3) ---
  [PASS] Dedicated S3 access and audit logging bucket provisioned
  [PASS] Log bucket lifecycle rules configured with transitions & expiration
  [PASS] Log objects expire automatically after retention period (365 days)
  [PASS] S3 server access logging enabled on state bucket

--- Test Suite 5: Cluster Autoscaler Kubernetes Deployment & RBAC (DoD #2) ---
  [PASS] Cluster Autoscaler ServiceAccount includes IRSA role annotation
  [PASS] Cluster Autoscaler RBAC defines node, pod eviction, and lease permissions
  [PASS] Cluster Autoscaler Deployment configures ASG tag auto-discovery
  [PASS] Burst scaling test workload targets Spot node group via nodeSelector

--- Test Suite 6: Terraform Syntax & Local Integration Validation ---
  [PASS] Terraform formatting is compliant in remote-state module
  [PASS] Terraform formatting is compliant in eks module
  [PASS] Terraform formatting is compliant in hms-core-stack

========================================================================
  RESULTS: All 30/30 tests PASSED! (100% Green)
  Definition of Done for TITANOPS-123 is FULLY SATISFIED. ✓
========================================================================
```

---

## 5. Interview Questions & Talking Points

### Q1: How do EKS Spot instance node groups work, and how do you protect against spot termination?
**Answer:** Spot instances are spare Amazon EC2 compute capacity available at up to a 90% discount compared to On-Demand prices. However, AWS can reclaim a Spot instance with a 2-minute interruption notice whenever it requires capacity. We protect against spot disruptions by:
1. **Separation of Concerns:** Running critical control-plane, databases, and monitoring pods on On-Demand nodes, while routing stateless microservices to Spot nodes using `nodeSelector: { capacity: spot }`.
2. **Instance Type Diversification:** Configuring multiple instance types (`t3.large`, `t3a.large`, `m5.large`, `m5a.large`) across multiple availability zones so that if one pool runs out of capacity, EKS launches nodes from alternative pools.
3. **AWS Node Termination Handler:** Intercepts EC2 Spot Interruption Warnings via EventBridge or IMDS, gracefully cordoning and draining pods onto surviving nodes before the 2-minute deadline expires.

### Q2: How does Cluster Autoscaler determine when to scale up or scale down nodes?
**Answer:**
- **Scale Up:** Cluster Autoscaler monitors for pods in `Pending` state that cannot be scheduled by kube-scheduler due to insufficient CPU, memory, or nodeSelector constraints. When pending pods are detected, it simulates scheduling against available node groups, chooses the optimal node group (using the `--expander=least-waste` algorithm), and increments the Auto Scaling Group's `DesiredCapacity`.
- **Scale Down:** It continuously evaluates node utilization. If a node's CPU/memory allocation drops below the threshold (e.g. 50%) for longer than `--scale-down-unneeded-time=2m`, and all pods on the node can be rescheduled elsewhere (respecting `PodDisruptionBudgets`), it cordons the node, evicts pods, and terminates the underlying EC2 instance.

### Q3: How do S3 lifecycle transition rules optimize cloud spend for state files and access logs?
**Answer:** S3 Standard storage costs ~$0.023 per GB/month. Noncurrent versions of Terraform state files and access logs are rarely accessed after creation. By establishing automated lifecycle policies:
- After 30 days, objects transition to **S3 Standard-IA** ($0.0125/GB/mo &rarr; **~45% savings**).
- After 60/90 days, objects transition to **S3 Glacier Flexible Retrieval** ($0.004/GB/mo &rarr; **~82% savings**).
- After 90 days (for state versions) or 365 days (for logs), objects expire and are deleted permanently.
- Additionally, setting `abort_incomplete_multipart_upload` after 7 days prevents charges for aborted uploads where chunks remain uncommitted in hidden storage.
