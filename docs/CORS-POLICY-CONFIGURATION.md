# TITANOPS-110: Explicit CORS Policy Across Services

## 1. Architectural Overview & Risk Mitigation
Cross-Origin Resource Sharing (CORS) is a browser security mechanism that restricts cross-origin HTTP requests initiated by scripts. When APIs lack an explicit CORS policy or employ unsafe wildcards (`*`), malicious web applications running in authenticated browsers can forge requests and steal protected healthcare data (violating **OWASP Top 10 - A05:2021 Security Misconfiguration**).

Prior to **TITANOPS-110**, services had no CORS configuration, functioning only through Nginx reverse proxy rewrites and remaining vulnerable if accessed directly or across decoupled environments.

---

## 2. Technical Implementation

### A. Explicit Whitelist Architecture
Implemented `user-service/src/main/java/com/medicore/hms/user/config/CorsConfig.java`:
* Explicitly whitelists known hospital origins:
  * Local development UI: `http://localhost:3000`, `http://localhost:5173`
  * Nginx gateway: `http://localhost:80`
  * Staging & Production domains: `https://medicore.hms`, `https://app.titanops.internal`
* Prohibits wildcards (`*`) in production configurations.

### B. Preflight (OPTIONS) Processing
* Configures `CorsFilter` with `Ordered.HIGHEST_PRECEDENCE` so browser preflight `OPTIONS` requests receive immediate CORS headers before reaching authentication filters.
* Restricts HTTP methods to: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `OPTIONS`.
* Configures `exposedHeaders` to expose `Authorization`, allowing client scripts to inspect tokens.

---

## 3. Definition of Done (DoD) Verification Matrix

| DoD Requirement | Description | Status | Verification |
| :--- | :--- | :---: | :--- |
| **DoD #1** | Explicit allowed-origins list defined without wildcards in production | **PASS** | `CorsConfig.java` |
| **DoD #2** | Preflight (OPTIONS) requests succeed for allowed origins and fail for others | **PASS** | `CorsConfigTest.java` (JUnit 5) |
| **DoD #3** | Allowed origins per environment documented | **PASS** | `docs/CORS-POLICY-CONFIGURATION.md` |
| **DoD #4** | Automated verification runner | **PASS** | `scripts/test-cors-policy.sh` (6/6 PASS) |
