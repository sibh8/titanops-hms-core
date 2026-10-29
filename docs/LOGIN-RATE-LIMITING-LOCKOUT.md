# TITANOPS-109: Login Rate Limiting and Account Lockout Protection

## 1. Executive Summary & Threat Profile
Without defensive brute-force throttling on credential endpoints, web applications are vulnerable to automated dictionary and credential stuffing attacks (violating **OWASP Top 10 - A07:2021 Identification and Authentication Failures**).

Prior to **TITANOPS-109**, `POST /api/auth/login` tracked failure metrics but allowed infinite unthrottled attempts, enabling attackers to execute high-frequency automated password guessing.

---

## 2. Technical Implementation

### A. Lockout & Throttling Architecture
Implemented `user-service/src/main/java/com/medicore/hms/user/security/LoginAttemptService.java`:
* **Brute-Force Threshold:** Configurable via `security.login.max-attempts` (default: 5 attempts).
* **Lockout Period:** Configurable via `security.login.lockout-duration-seconds` (default: 900s / 15 minutes).
* **HTTP 429 Status:** When locked, `POST /api/auth/login` immediately short-circuits with `429 Too Many Requests` returning remaining seconds:
```json
{
  "error": "Too Many Requests",
  "message": "Account is temporarily locked due to multiple failed login attempts. Please try again later.",
  "remainingSeconds": 874
}
```

### B. Observability & Security Metrics
* Added Micrometer counter `medicore.user.account.lockouts.total` tagged with `service=user-service`.
* Emits high-visibility security audit log warnings upon each failure and errors upon lockout activation.

### C. Access Recovery
* **Time-Based Automatic Unlock:** When the lockout duration expires, incoming requests automatically purge the cached lockout state and restore user access without administrator intervention.
* **Administrative Reset:** Implemented `POST /api/users/{username}/unlock` protected by RBAC (`role=ADMIN`), allowing hospital security administrators to immediately reset lockouts for legitimate personnel.

---

## 3. Definition of Done (DoD) Verification Matrix

| DoD Requirement | Description | Status | Verification |
| :--- | :--- | :---: | :--- |
| **DoD #1** | Repeated failed logins from same user/IP are throttled/locked out | **PASS** | `LoginAttemptService.java`, `AuthController.java` (HTTP 429) |
| **DoD #2** | Lockout state is observable via Micrometer metric & audit log | **PASS** | `medicore.user.account.lockouts.total` |
| **DoD #3** | Legitimate users recover access via time-based unlock or admin reset | **PASS** | `POST /api/users/{username}/unlock` & auto-expiry |
| **DoD #4** | Automated verification runner | **PASS** | `scripts/test-login-rate-limiting.sh` (7/7 PASS) |
