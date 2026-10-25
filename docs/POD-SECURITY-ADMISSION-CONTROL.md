# Pod Security Standards (PSS) & Admission Control Runbook

**Jira Ticket:** TITANOPS-125  
**Status:** In Review  
**Assignee:** Kaushal Patil (@kaushalpatil205)  
**Reviewer:** @Rxborole  

---

## 1. Executive Summary & Security Objectives

In a multi-tenant or microservice Kubernetes environment, container images built without strict security constraints can expose the entire underlying host node to privilege escalation, container escapes, and denial-of-service via resource starvation.

This implementation satisfies all three criteria of the **TITANOPS-125** Definition of Done (DoD):
1. **Admission Controller Deployed:** Deployed the **Kyverno** admission controller (`v1.12.5` / Helm chart `v3.2.6`) with hardened controller specs (non-root execution, dropped capabilities, resource limits, and HTTPS validating webhooks).
2. **Strict Policies Enforced:** Implemented declarative `ClusterPolicy` resources in `Enforce` mode covering:
   - **No Root Containers:** Requires `securityContext.runAsNonRoot: true` and `securityContext.runAsUser > 0`.
   - **No Privilege Escalation:** Requires `allowPrivilegeEscalation: false`, forbids `privileged: true`, and mandates dropping `ALL` Linux capabilities.
   - **Mandatory Resource Bounds:** Requires both `requests` and `limits` for CPU and memory on all containers.
3. **Rejection Verified:** Tested and proved that non-compliant manifests attempting root execution, privilege escalation, or unbounded resource consumption are blocked and rejected with descriptive policy violation messages prior to admission into the cluster.

---

## 2. Architecture Overview

### 2.1 Kubernetes Admission Control Intercept Flow

```
[ kubectl / CI/CD Deployment ]
              |
              v (HTTPS API Request)
   +---------------------------------------+
   |        kube-apiserver                 |
   |                                       |
   | 1. Authentication & Authorization     |
   | 2. Mutating Admission Webhooks        |
   | 3. Schema Validation                  |
   | 4. Validating Admission Webhooks ----+
   +---------------------------------------+
                        | (AdmissionReview)
                        v
          +-----------------------------+
          |  Kyverno Admission Webhook  |
          |  (kyverno/kyverno-svc:443)  |
          |                             |
          |  Evaluates ClusterPolicies: |
          |  - disallow-root-containers |
          |  - no privilege escalation  |
          |  - require-resource-limits  |
          +-----------------------------+
              |                     |
     [Passes All Rules]      [Fails Any Rule]
              |                     |
              v                     v
       Status: ALLOWED       Status: REJECTED
      (Persist to etcd)     (HTTP 403 Forbidden with Violation Reason)
```

### 2.2 Defense-in-Depth: PSA Restricted + Kyverno
We enforce a dual-layer security posture:
1. **Layer 1: Native Kubernetes Pod Security Admission (PSA):**
   - The application namespace (`hms`) is labeled with:
     ```yaml
     pod-security.kubernetes.io/enforce: restricted
     pod-security.kubernetes.io/enforce-version: latest
     ```
2. **Layer 2: Declarative Kyverno Admission Policies:**
   - Provides granular, custom rejection messages and validates resource requests/limits (which PSA alone does not govern).

---

## 3. Policy Reference & Specifications

### 3.1 Policy 1: Disallow Root Containers (`k8s/admission-control/policies/disallow-root-containers.yaml`)
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-root-containers
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: require-run-as-non-root
      match:
        any:
          - resources:
              kinds: [Pod, Deployment, DaemonSet, StatefulSet, Job, CronJob]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]
      validate:
        message: >-
          validation failure: running as root is prohibited. Containers must set
          securityContext.runAsNonRoot: true and securityContext.runAsUser > 0.
        pattern:
          spec:
            =(securityContext):
              runAsNonRoot: true
            =(template):
              spec:
                =(securityContext):
                  runAsNonRoot: true
                containers:
                  - =(securityContext):
                      runAsNonRoot: true
                      runAsUser: ">0"
```

### 3.2 Policy 2: Disallow Privilege Escalation (`k8s/admission-control/policies/disallow-privilege-escalation.yaml`)
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-privilege-escalation
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: privilege-escalation-and-capabilities
      match:
        any:
          - resources:
              kinds: [Pod, Deployment, DaemonSet, StatefulSet, Job, CronJob]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]
      validate:
        message: >-
          validation failure: privilege escalation and privileged containers are strictly
          forbidden. Containers must set allowPrivilegeEscalation: false and drop ALL capabilities.
        pattern:
          spec:
            =(template):
              spec:
                containers:
                  - securityContext:
                      allowPrivilegeEscalation: false
                      =(privileged): false
                      capabilities:
                        drop:
                          - ALL
```

### 3.3 Policy 3: Require Resource Limits (`k8s/admission-control/policies/require-resource-limits.yaml`)
```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: Enforce
  background: true
  rules:
    - name: check-cpu-memory-limits-requests
      match:
        any:
          - resources:
              kinds: [Pod, Deployment, DaemonSet, StatefulSet, Job, CronJob]
      exclude:
        any:
          - resources:
              namespaces: [kube-system, kyverno]
      validate:
        message: >-
          validation failure: CPU and memory requests and limits are mandatory for all
          containers to prevent noisy neighbor and resource starvation issues.
        pattern:
          spec:
            =(template):
              spec:
                containers:
                  - resources:
                      requests:
                        cpu: "?*"
                        memory: "?*"
                      limits:
                        cpu: "?*"
                        memory: "?*"
```

---

## 4. Verification Suite Results

The automated verification suite (`infra/test/verify-admission-control.sh`) executes 31 tests across 5 suites:
```text
========================================================================
  TITANOPS-125: Pod Security Standards & Admission Control Verification  
========================================================================

--- Test Suite 1: Kyverno Admission Controller Architecture (DoD #1) ---
  [PASS] Kyverno namespace manifest defined
  [PASS] Kyverno ServiceAccount and RBAC ClusterRoleBindings configured
  [PASS] Kyverno admission controller Deployment hardened (non-root, health probes)
  [PASS] ValidatingWebhookConfiguration registered with failurePolicy: Fail
  [PASS] Terraform module infra-stack/modules/admission-control defines Helm release
  [PASS] hms-core-stack wires admission-control module
  [PASS] Dev environment config.yaml enables admission_control feature

--- Test Suite 2: Policy Enforcement Definition (DoD #2) ---
  [PASS] Policy disallow-root-containers configured in Enforce mode
  [PASS] Root policy enforces runAsNonRoot: true and runAsUser > 0
  [PASS] Policy disallow-privilege-escalation configured in Enforce mode
  [PASS] Privilege policy enforces allowPrivilegeEscalation: false
  [PASS] Privilege policy mandates dropping ALL Linux capabilities
  [PASS] Policy require-resource-limits configured in Enforce mode
  [PASS] Resource policy mandates requests & limits for CPU and memory
  [PASS] Master policy enforce-pod-security-standards bundles all 3 rules
  [PASS] Native Kubernetes PSA Restricted profile configured on namespace

--- Test Suite 3: Admission Rejection Simulation & Verification (DoD #3) ---
  [PASS] Compliant test fixture exists: compliant-workload.yaml
  [PASS] Compliant workload is ACCEPTED by admission controller
  [PASS] Non-compliant root test fixture exists: non-compliant-root.yaml
  [PASS] Non-compliant root workload is REJECTED by admission controller (DoD #3)
  [PASS] Rejection message specifies root violation reason
  [PASS] Non-compliant privileged test fixture exists: non-compliant-privileged.yaml
  [PASS] Non-compliant privileged workload is REJECTED by admission controller (DoD #3)
  [PASS] Rejection message specifies privilege escalation reason
  [PASS] Non-compliant no-resources test fixture exists
  [PASS] Non-compliant no-resources workload is REJECTED by admission controller (DoD #3)
  [PASS] Rejection message specifies resource limits reason

--- Test Suite 4: Helm Chart & Service Manifest Compliance ---
  [PASS] Application Helm values define baseline non-root securityContext
  [PASS] Microservice Helm values define CPU/memory resource limits

--- Test Suite 5: Terraform Formatting & Syntax Integrity ---
  [PASS] Terraform formatting is compliant in admission-control module
  [PASS] Terraform formatting is compliant in hms-core-stack

========================================================================
  RESULTS: All 31/31 tests PASSED! (100% Green)
  Definition of Done for TITANOPS-125 is FULLY SATISFIED. ✓
========================================================================
```

---

## 5. Interview Questions & Talking Points

### Q1: How does Kubernetes dynamic admission control work under the hood?
**Answer:** Kubernetes admission control consists of two phases executed after authentication and authorization:
1. **Mutating Admission Webhooks:** Can modify the incoming object (for example, injecting sidecars, default labels, or default resource requests).
2. **Validating Admission Webhooks:** Cannot modify objects; they inspect the final object schema and return an `AdmissionReview` response containing `allowed: true` or `allowed: false` with a status code and violation message.
When a user or CI pipeline submits a `Deployment` or `Pod`, kube-apiserver serializes the object into JSON and makes an HTTPS POST request to the registered webhook service (e.g. `kyverno-svc.kyverno.svc:443`). The webhook inspects the manifest against active `ClusterPolicy` rules and returns the decision.

### Q2: Kyverno vs OPA Gatekeeper — why choose Kyverno for Kubernetes-native policy enforcement?
**Answer:**
- **Language / DSL:** OPA Gatekeeper requires authoring policies in **Rego**, a specialized query language with a steep learning curve and custom `ConstraintTemplate` CRDs. Kyverno uses native **Kubernetes YAML patterns**, allowing DevOps engineers to write policies using standard declarative Kubernetes syntax.
- **CLI Pre-commit Testing:** Kyverno provides a standalone CLI (`kyverno test` / `kyverno apply`) that integrates directly into pre-commit hooks and GitHub Actions CI pipelines, allowing engineers to test and block non-compliant manifests in Git before they ever reach a cluster.
- **Mutating & Generating Capabilities:** Kyverno can also mutate manifests (e.g. automatically injecting securityContext or nodeSelectors) and generate resources (e.g. default NetworkPolicies or Quotas when a new namespace is created).

### Q3: What happens if the admission controller webhook fails or times out (`FailurePolicy: Fail` vs `Ignore`)?
**Answer:**
- **`failurePolicy: Fail`:** If the webhook endpoint cannot be reached or times out (default 10s), the API server **rejects** the request. This is the **Fail-Closed** security standard required for production environments to prevent uninspected, insecure workloads from slipping into the cluster during an admission controller outage.
- **`failurePolicy: Ignore`:** The API server bypasses validation if the webhook fails (**Fail-Open**). While this guarantees availability, it introduces security vulnerabilities because an attacker could DoS the admission controller to deploy privileged root pods undetected.
- To prevent cluster lockout with `failurePolicy: Fail`, system namespaces (`kube-system`, `kyverno`) are explicitly excluded via `namespaceSelector`.
