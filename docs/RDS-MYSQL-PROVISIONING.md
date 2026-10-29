# AWS RDS MySQL Infrastructure Provisioning (TITANOPS-67)

## Overview & Background
In local development, TitanOps HMS utilizes a single containerized MySQL 8.0 instance configured in `docker-compose.yml`, exposing database `medicore_hms` to the 9 Java microservices. For enterprise production deployments on AWS, containerized databases create single points of failure, lack automated backup/failover mechanisms, and do not provide encrypted data storage.

Under **TITANOPS-67**, the ephemeral containerized database is replaced with an enterprise-grade AWS RDS MySQL 8.0 cluster provisioned via Terraform infrastructure-as-code.

---

## Architectural Implementation

### 1. Network Placement & Isolation
- **Subnet Group**: Provisioned exclusively within private VPC subnets (`private_subnet_ids`) across multiple Availability Zones, ensuring zero exposure to the public internet.
- **Security Group Isolation**:
  - Ingress: Restricts TCP port 3306 exclusively to the EKS cluster worker nodes security group (`var.eks_cluster_security_group_id`) and administrative Bastion host (`var.bastion_security_group_id`).
  - No public CIDR (`0.0.0.0/0`) ingress is permitted.

### 2. High Availability & Data Protection
- **Multi-AZ Redundancy**: Automatic failover to a synchronous standby replica in a secondary Availability Zone.
- **KMS Storage Encryption**: Data at rest encrypted via dedicated AWS Customer Managed Key (CMK) with automated annual rotation.
- **Automated Backups**: Configurable retention period (default 7 days) with point-in-time recovery.

### 3. Spring Boot Datasource Integration
The RDS module produces standard connection outputs consumed by Kubernetes Secrets and Helm deployments:
```hcl
output "jdbc_connection_url" {
  description = "Standard JDBC formatted connection URL for Spring Boot microservices"
  value       = "jdbc:mysql://${aws_db_instance.this.endpoint}/${aws_db_instance.this.db_name}?useSSL=true&requireSSL=true&verifyServerCertificate=false&allowPublicKeyRetrieval=true"
}
```

Microservices map the JDBC URL directly to their Spring environment:
- `SPRING_DATASOURCE_URL`: Provided via Terraform output / Kubernetes Secret
- `SPRING_DATASOURCE_USERNAME`: `medicore`
- `SPRING_DATASOURCE_PASSWORD`: Securely retrieved via Secrets Manager / K8s Secret

---

## Verification & Automated Testing
The provisioning configuration is validated by `scripts/test-rds-mysql-provisioning.sh`:
- Terraform canonical formatting (`terraform fmt`) and module syntax (`terraform validate`).
- Engine type verification (`mysql` 8.0.x).
- Private subnet placement and security group ingress rule constraints.
- Output parameter availability and JDBC connection format compliance.
