# MediCore HMS — Kubernetes NetworkPolicies

This directory contains the Kubernetes NetworkPolicy specifications for **MediCore HMS**, implementing a **Zero-Trust Network Segmentation** architecture for compliance with **HIPAA Security Rule §164.312(e)** and **CIS Kubernetes Benchmark 5.3.2**.

---

## 1. Architecture Overview

By default, Kubernetes flat networking allows any pod in the cluster to communicate with any other pod, including databases and internal microservices.

These NetworkPolicies enforce strict network perimeter controls:
- **Default Deny All (`00-default-deny-all.yaml`)**: Blocks all incoming (Ingress) and outgoing (Egress) traffic by default for all pods in the namespace.
- **DNS Egress (`01-allow-dns.yaml`)**: Explicitly permits CoreDNS / kube-dns traffic on port 53 (UDP/TCP) so pods can resolve service endpoints.
- **Frontend Policy (`02-frontend-network-policy.yaml`)**: Allows external/ALB ingress on port 80, allows egress to the 9 backend microservices (ports 8081–8089) and OpenTelemetry (port 4318). **Strictly denies egress to MySQL (port 3306)**.
- **Backend Services Policy (`03-backend-services-network-policy.yaml`)**: Restricts inbound API traffic exclusively to the frontend pod and Prometheus scrapers. Restricts egress strictly to MySQL (port 3306), DNS (port 53), and OpenTelemetry (port 4317).
- **Database Policy (`04-database-network-policy.yaml`)**: Permits inbound MySQL connections on port 3306 **only** from authorized backend microservices. Completely denies connections from frontend and unauthorized pods.
- **Observability Policy (`05-observability-network-policy.yaml`)**: Regulates ingestion traffic to OpenTelemetry Collector and Prometheus metrics endpoints.

---

## 2. Traffic Flow Matrix

| Source Pod | Destination | Target Port | Status | Rationale |
|---|---|---|---|---|
| Ingress / ALB | `frontend` | 80 / TCP | **ALLOWED** | Public web traffic entry point |
| `frontend` | CoreDNS (`kube-system`) | 53 / UDP, TCP | **ALLOWED** | In-cluster service discovery |
| `frontend` | 9 Backend Services | 8081–8089 / TCP | **ALLOWED** | Reverse-proxy API calls (`/api/*`) |
| `frontend` | `otel-collector` | 4318 / TCP | **ALLOWED** | Client-side & nginx OpenTelemetry traces |
| **`frontend`** | **`medicore-mysql` / RDS** | **3306 / TCP** | **BLOCKED** | **CRITICAL: Frontend has no direct DB access** |
| 9 Backend Services | CoreDNS (`kube-system`) | 53 / UDP, TCP | **ALLOWED** | Service discovery & RDS hostname resolution |
| 9 Backend Services | `medicore-mysql` / RDS | 3306 / TCP | **ALLOWED** | Spring Boot JPA / Hibernate JDBC persistence |
| 9 Backend Services | `otel-collector` | 4317 / TCP | **ALLOWED** | Spring Boot OpenTelemetry Java agent (gRPC) |
| Unauthorized / Rogue Pod | `medicore-mysql` | 3306 / TCP | **BLOCKED** | Prevents lateral movement in case of pod compromise |
| Unauthorized / Rogue Pod | Backend Services | 8081–8089 / TCP | **BLOCKED** | Protects internal microservices from cluster rogue traffic |

---

## 3. Deployment Instructions

### Applying with Kustomize
```bash
# Apply to default 'hms' namespace
kubectl apply -k k8s/network-policies/

# Or override target namespace
kubectl apply -k k8s/network-policies/ -n my-namespace
```

### Applying with kubectl direct
```bash
kubectl apply -f k8s/network-policies/ -n hms
```

---

## 4. Verification and DoD Testing

To verify the policies against an active cluster or validate dry-run schemas:
```bash
chmod +x k8s/network-policies/verify-network-policies.sh
./k8s/network-policies/verify-network-policies.sh
```

The verification suite automatically tests:
1. Syntax and API validation via `kubectl --dry-run=client`
2. Frontend to Backend connectivity (Port 8081) — **ALLOWED**
3. Backend to MySQL Database connectivity (Port 3306) — **ALLOWED**
4. **Negative Test**: Frontend to MySQL Database connectivity (Port 3306) — **DENIED**
5. **Negative Test**: Unauthorized pod to Database connectivity (Port 3306) — **DENIED**
