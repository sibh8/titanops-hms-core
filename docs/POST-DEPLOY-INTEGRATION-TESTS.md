# TitanOps HMS: Post-Deploy Integration Verification Job

## Overview
This document details the automated post-deployment integration test pipeline configured in GitHub Actions under ticket **TITANOPS-73**.

Rather than stopping pipeline execution after Kubernetes pods roll out, a dedicated post-deploy verification job triggers immediately after successful deployment to run the comprehensive Node.js integration test suite against the target EKS environment.

---

## CI/CD Pipeline Lifecycle with Post-Deploy Verification

```
  ┌─────────────────────────────────────────────────────────────┐
  │ 1. Build & Package (build)                                  │
  │    - Maven compile Spring Boot services                     │
  │    - Vite build React frontend                              │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ 2. Automated Testing & Scans (test)                         │
  │    - Unit tests & SonarQube code quality                     │
  │    - Trivy vulnerability & secret scans                     │
  └──────────────────────────────┬──────────────────────────────┘
                                 │
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ 3. Helm Deployment to EKS (deploy)                          │
  │    - Atomic Helm upgrade with rollback protection           │
  │    - Pod rollout readiness verification                     │
  └──────────────────────────────┬──────────────────────────────┘
                                 │ (needs: [deploy])
                                 ▼
  ┌─────────────────────────────────────────────────────────────┐
  │ 4. Post-Deploy Integration Verification                     │
  │    (post-deploy-integration-tests)                          │
  │    - Executes tests/00-health through 10-cross-service      │
  │    - Validates cross-service transactional integrity        │
  │    - Uploads test-reports artifact (retention: 14 days)     │
  └─────────────────────────────────────────────────────────────┘
```

---

## 1. Job Specification (`.github/workflows/ci-cd.yml`)

```yaml
post-deploy-integration-tests:
  name: Post-Deploy Integration Verification
  needs: [deploy]
  runs-on: ubuntu-latest
  if: needs.deploy.result == 'success'
  steps:
    - name: Checkout repository
      uses: actions/checkout@v4.2.2

    - name: Setup Node.js
      uses: actions/setup-node@v4.2.0
      with:
        node-version: '20'

    - name: Run Integration Test Suite
      working-directory: integration-tests
      run: |
        mkdir -p ../test-reports
        set -o pipefail
        ./run-tests.sh 2>&1 | tee ../test-reports/integration-test-results.log

    - name: Upload Integration Test Reports as Artifact
      if: always()
      uses: actions/upload-artifact@v4.6.1
      with:
        name: integration-test-reports
        path: test-reports/
        retention-days: 14
```

---

## 2. Tested Integration Suites

| Suite | File | Coverage |
| :--- | :--- | :--- |
| Health Checks | `00-health.test.js` | Actuator `/health` on all 9 microservices. |
| User Service | `01-users.test.js` | User registration, authentication, RBAC. |
| Provider Service | `02-providers.test.js` | Physician directory, scheduling availability. |
| Patient Service | `03-patients.test.js` | Patient demographics, EHR records. |
| Appointments | `04-appointments.test.js` | Booking, rescheduling, status lifecycle. |
| Encounters | `05-encounters.test.js` | Clinical encounter documentation. |
| Lab Service | `06-lab.test.js` | Lab orders, test status, result logging. |
| Medications | `07-medications.test.js` | Pharmacy formulary and stock levels. |
| Prescriptions | `08-prescriptions.test.js` | Drug prescription issuance. |
| Billing Service | `09-billing.test.js` | Invoice generation, payments. |
| Cross-Service | `10-cross-service.test.js` | End-to-end patient workflow spanning all 9 services. |

---

## 3. Verification Suite

Run the automated test runner:
```bash
./scripts/test-post-deploy-integration-job.sh
```

Expected output:
```
==============================================================================
   TitanOps HMS: Post-Deploy Integration Job Verification (TITANOPS-73)       
==============================================================================

Phase 1: CI/CD Workflow Job Definition
  [PASS] 1. post-deploy-integration-tests job defined in ci-cd.yml
  [PASS] 2. Job explicitly declares dependency on deployment (needs: [deploy])
  [PASS] 3. Job enforces conditional execution only on successful deployment

Phase 2: Test Execution & Artifact Upload
  [PASS] 4. Job executes run-tests.sh test runner
  [PASS] 5. Job uploads test report log as GitHub Actions artifact

Phase 3: Integration Test Suite Completeness
  [PASS] 6. Integration test directory contains all 11 test suites (00-health to 10-cross-service)
  [PASS] 7. Test runner script run-tests.sh is executable and syntax valid

Phase 4: Architecture Documentation
  [PASS] 8. Post-deploy integration testing documentation exists

==============================================================================
   Summary: 8 Passed, 0 Failed
==============================================================================
All post-deploy integration job tests passed successfully!
```
