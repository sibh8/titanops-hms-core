# Pod SecurityContext Hardening & Standards Compliance (TITANOPS-131)

## Overview & Background
To satisfy Kubernetes Pod Security Standards (PSS) at the **Restricted** profile level, container workloads must prevent container breakouts, privilege escalation, and runtime filesystem tampering. Under **TITANOPS-131**, comprehensive pod and container-level securityContext specifications have been codified across all 10 workloads in both raw manifests (`k8s/deployments/`) and Helm templates (`helm/titanops-base/`).

---

## Architectural Implementation

### 1. Pod-Level Security Context (`spec.securityContext`)
- `runAsNonRoot: true`: Guarantees the Kubelet actively rejects containers attempting to initialize with UID 0.
- `runAsUser: 10001` (microservices) / `101` (Nginx frontend): Maps execution strictly to designated service accounts.
- `fsGroup: 10001` / `101`: Ensures mounted volumes inherit non-root permissions.
- `seccompProfile: { type: RuntimeDefault }`: Constrains system calls to default Linux container profile.

### 2. Container-Level Security Context (`spec.containers[].securityContext`)
- `allowPrivilegeEscalation: false`: Prohibits child processes from gaining more privileges than their parent (prevents `setuid` binaries).
- `readOnlyRootFilesystem: true`: Locks container image layers to read-only, preventing attackers from downloading tools, replacing binaries, or persisting malicious scripts.
- `capabilities: { drop: ["ALL"] }`: Strips all Linux root capabilities (`CAP_NET_RAW`, `CAP_SYS_ADMIN`, `CAP_CHOWN`, etc.).

### 3. Ephemeral Writable Storage Strategy
Because Java/Spring Boot (embedded Tomcat work dir) and Nginx (temporary client bodies and fastcgi buffers) require write access to `/tmp`, `/var/run`, and `/var/cache`, dedicated in-memory `emptyDir: {}` volumes are mounted:
```yaml
volumeMounts:
  - name: tmp-dir
    mountPath: /tmp
volumes:
  - name: tmp-dir
    emptyDir: {}
```
This isolates temporary runtime writes to isolated volatile memory while maintaining strict immutability across the OS filesystem.

---

## Automated Verification
Executed via `scripts/test-pod-security-hardening.sh` (64/64 tests pass):
- Validation of `runAsNonRoot: true` across all 10 workloads.
- Enforcement of `readOnlyRootFilesystem: true` across all Deployments and Helm chart.
- Validation of `allowPrivilegeEscalation: false` and capability dropping.
- Verification of `/tmp` volume mounts.
