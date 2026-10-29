# TITANOPS-107: JWT-Based Authentication and Per-Endpoint Authorization

## 1. Architectural Overview & Threat Modeling
In zero-trust microservice environments, relying solely on boundary firewalls is insufficient. All inbound API calls across microservices must present a cryptographically verified identity token to prevent unauthorized access and privilege escalation.

Prior to **TITANOPS-107**, `POST /api/auth/login` authenticated credentials via BCrypt but simply returned the raw `User` entity without issuing an identity token. Downstream microservices operated completely unauthenticated, and the existing `User.role` database column (`STAFF`/`ADMIN`) was unverified at runtime.

---

## 2. Technical Implementation

### A. JWT Token Issuance & Cryptographic Engine
Implemented `user-service/src/main/java/com/medicore/hms/user/security/JwtUtil.java`:
* Generates standard RFC 7519 HMAC-SHA256 signed JSON Web Tokens.
* Payload encodes subject (`sub`: username), `userId`, `role` (`STAFF`/`ADMIN`), `iat` (issued-at), and `exp` (expiration set to 24 hours).
* Employs constant-time signature comparison via `MessageDigest.isEqual` to prevent timing side-channel attacks.

### B. Login Token Issuance
Updated `AuthController.java`:
* `POST /api/auth/login` returns:
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "type": "Bearer",
  "expiresIn": 86400,
  "user": {
    "id": 1,
    "username": "dr_smith",
    "role": "STAFF"
  }
}
```

### C. Security Filter & Role-Based Access Control (RBAC)
Implemented `user-service/src/main/java/com/medicore/hms/user/security/JwtAuthFilter.java`:
* Intercepts incoming requests at `@Order(1)`.
* Bypasses public endpoints: `/api/auth/**`, `/actuator/**`, and `OPTIONS` preflight requests.
* Enforces HTTP 401 Unauthorized for missing, tampered, or expired tokens.
* Enforces HTTP 403 Forbidden on destructive operations (`DELETE`) unless the caller possesses role `ADMIN`.

### D. Frontend Client Integration
Updated `frontend/src/pages/LoginPage.jsx` and `frontend/src/api/apiClient.js`:
* `LoginPage.jsx` extracts `res.data.token` and stores it into `localStorage.setItem('auth_token', token)`.
* Axios request interceptor attaches `Authorization: Bearer <token>` to all subsequent HTTP requests.
* Global 401 response interceptor purges expired tokens and redirects unauthenticated users to `/login`.

---

## 3. Definition of Done (DoD) Verification Matrix

| DoD Requirement | Description | Status | Verification |
| :--- | :--- | :---: | :--- |
| **DoD #1** | `POST /api/auth/login` returns signed JWT token with expiry | **PASS** | `JwtUtil.java`, `AuthController.java` |
| **DoD #2** | Filter rejects missing/invalid/expired tokens with HTTP 401 | **PASS** | `JwtAuthFilter.java`, `JwtUtilTest.java` |
| **DoD #3** | Role-based access control enforces `role=ADMIN` or returns HTTP 403 | **PASS** | `JwtAuthFilter.java` |
| **DoD #4** | Frontend updated to attach token to all outgoing API calls | **PASS** | `LoginPage.jsx`, `apiClient.js` |
| **DoD #5** | Automated verification runner | **PASS** | `scripts/test-jwt-authentication.sh` (8/8 PASS) |
