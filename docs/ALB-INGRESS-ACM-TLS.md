# AWS Load Balancer Controller with ACM TLS & HTTPS-Only Redirection
**Ticket Reference:** `TITANOPS-128`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Manifests:** `k8s/ingress/`, `terraform/modules/ingress/`

---

## 1. Context & Motivation

Previously, the TitanOps HMS frontend and API services were exposed over plain HTTP or internal ClusterIPs with no TLS termination. This exposed sensitive electronic protected health information (ePHI) to interception.

`TITANOPS-128` provisions the AWS Load Balancer Controller and an Application Load Balancer (ALB) with an AWS Certificate Manager (ACM) TLS certificate, enforcing strict HTTP-to-HTTPS (port 80 to 443) redirection so that all public traffic is encrypted in transit.

---

## 2. Infrastructure as Code (Terraform)

Located in `terraform/modules/ingress/`:
- **ACM Certificate (`aws_acm_certificate.alb_tls`)**:
  - RSA 2048-bit key algorithm.
  - Covers primary domain (`titanops.internal`) and SAN wildcards (`*.titanops.internal`, `api.titanops.internal`, `app.titanops.internal`).
- **AWS Load Balancer Controller IRSA (`aws_iam_role.aws_load_balancer_controller`)**:
  - Granular trust policy binding strictly to `system:serviceaccount:kube-system:aws-load-balancer-controller`.
  - Scoped permissions for Elastic Load Balancing v2, EC2 network interface management, ACM certificate queries, and AWS WAF integration.

---

## 3. Kubernetes Ingress Architecture

Located in `k8s/ingress/`:
1. `00-aws-load-balancer-controller.yaml`:
   - Declares the `IngressClass` `alb` managed by `ingress.k8s.aws/alb`.
   - Provisions ServiceAccount `aws-load-balancer-controller` with IRSA role annotation.
2. `01-alb-ingress-tls.yaml`:
   - Configures the Ingress resource terminating TLS at the edge.
   - Key Annotations:
     - `alb.ingress.kubernetes.io/scheme: internet-facing`
     - `alb.ingress.kubernetes.io/target-type: ip`
     - `alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'`
     - `alb.ingress.kubernetes.io/ssl-redirect: '443'` (Forces immediate 301 redirection to HTTPS)
     - `alb.ingress.kubernetes.io/certificate-arn: <acm-cert-arn>`
   - Unified Routing Table:
     - `/` $\rightarrow$ `frontend:80`
     - `/api/v1/patients` $\rightarrow$ `patient-service:8081`
     - `/api/v1/appointments` $\rightarrow$ `appointment-service:8082`
     - `/api/v1/billing` $\rightarrow$ `billing-service:8083`
     - `/api/v1/users`, `/api/v1/auth` $\rightarrow$ `user-service:8084`
     - `/api/v1/encounters` $\rightarrow$ `encounter-service:8085`
     - `/api/v1/labs` $\rightarrow$ `lab-service:8086`
     - `/api/v1/medications` $\rightarrow$ `medication-service:8087`
     - `/api/v1/prescriptions` $\rightarrow$ `prescription-service:8088`
     - `/api/v1/providers` $\rightarrow$ `provider-service:8089`

---

## 4. Verification

The automated verification suite in `scripts/test-alb-ingress-tls.sh` validates:
- Terraform module validation (`terraform validate`).
- ACM TLS certificate declaration and RSA 2048 encryption.
- IRSA role configuration and IAM policy completeness.
- IngressClass and Ingress YAML parsing.
- Dual-port listening (80/443) and SSL redirect (443).
- Comprehensive routing to frontend and all 9 microservices.

Execution:
```bash
./scripts/test-alb-ingress-tls.sh
```
All 11 automated verification checks pass.
