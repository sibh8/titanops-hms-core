# Centralized Log Aggregation & CloudWatch Retention Policy
**Ticket Reference:** `TITANOPS-132`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Components:** `terraform/modules/logging/`, `k8s/logging/`

---

## 1. Executive Summary

While distributed tracing captures request flows across microservices via OpenTelemetry and Jaeger, raw application stdout and container runtime diagnostic logs previously remained ephemeral on local node disks. In production, unaggregated logs hinder root-cause analysis, post-incident forensics, and compliance audits.

`TITANOPS-132` provisions a centralized log aggregation pipeline using **AWS CloudWatch Container Insights** and an in-cluster **Fluent Bit DaemonSet**, with strict retention rules to control storage costs and fulfill healthcare audit regulations.

---

## 2. Infrastructure as Code (Terraform)

Located in `terraform/modules/logging/`:
- **CloudWatch Log Groups**:
  - `/aws/containerinsights/${var.cluster_name}/application`: Stores stdout/stderr streams from all 10 application containers.
  - `/aws/containerinsights/${var.cluster_name}/dataplane`: Captures kubelet, kube-proxy, and containerd runtime events.
  - `/aws/containerinsights/${var.cluster_name}/host`: Captures EC2 node system logs (`/var/log/messages`, `/var/log/secure`).
- **Retention Policy**:
  - Configured with `retention_in_days = 30` (or 90 days for audit compliance), automatically pruning expired log streams.
- **IAM IRSA Role**:
  - Scoped policy permitting `logs:CreateLogStream`, `logs:DescribeLogStreams`, and `logs:PutLogEvents` solely on the cluster's log group ARNs.
  - Bound to `system:serviceaccount:amazon-cloudwatch:fluent-bit`.

---

## 3. Kubernetes DaemonSet & Shipping Pipeline

Located in `k8s/logging/`:
- `01-fluent-bit-namespace-rbac.yaml`:
  - Dedicated `amazon-cloudwatch` namespace.
  - RBAC ClusterRole and ClusterRoleBinding permitting log reading and pod metadata enrichment.
- `02-fluent-bit-configmap.yaml`:
  - High-performance tail input reading `/var/log/containers/*.log`.
  - Kubernetes filter parsing Docker and CRI-O structured log lines, tagging each stream with namespace, pod, and container names.
  - CloudWatch Logs output plugin streaming parsed logs to the designated regional log group.
- `03-fluent-bit-daemonset.yaml`:
  - Deploys `amazon/aws-for-fluent-bit:2.32.0` across all cluster nodes.

---

## 4. Multi-Service Searchability & Filtering

Logs across all 9 Java microservices and the Vite frontend are structured and queryable in CloudWatch Insights using standard filter expressions:
```sql
fields @timestamp, log_processed.level, log_processed.message, kubernetes.pod_name
| filter kubernetes.container_name in ["patient-service", "billing-service", "user-service"]
| filter log_processed.level = "ERROR"
| sort @timestamp desc
| limit 100
```

---

## 5. Verification

The test suite in `scripts/test-centralized-logging.sh` validates:
- Terraform logging module syntax and provider configuration.
- Application, dataplane, and host log groups with defined retention (30 days).
- Fluent Bit IRSA role and scoped policy declarations.
- Kubernetes Namespace, ServiceAccount, ConfigMap, and DaemonSet YAML syntax.
- Multi-service query filtering simulation across `patient-service`, `billing-service`, and `user-service`.

Execution:
```bash
./scripts/test-centralized-logging.sh
```
All 9 automated checks pass.
