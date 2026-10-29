# TITANOPS-108: Stop Leaking Password Hashes in API Responses

## 1. Executive Summary & Security Risk Analysis
In healthcare management systems (HMS) subject to HIPAA compliance and zero-trust security standards, sensitive credentials and cryptographic hashes must never leave server-side application boundaries. 

Prior to this fix, the `com.medicore.hms.user.model.User` JPA entity in `user-service` lacked Jackson serialization suppression annotations on its `password` field. Consequently, whenever endpoints returned a `User` entity (e.g. `POST /api/auth/register`, `POST /api/auth/login`, `GET /api/users`, `GET /api/users/{id}`, `GET /api/users/username/{username}`), Jackson serialized all fields, leaking the one-way BCrypt hash to client browsers, proxies, and API logs. 

Exposing password hashes facilitates offline dictionary, rainbow table, and brute-force GPU attacks against user credentials (violating **OWASP Top 10 - A02:2021 Cryptographic Failures** and **A01:2021 Broken Access Control**).

---

## 2. Technical Implementation

### A. Jackson Write-Only Property Mapping
In `user-service/src/main/java/com/medicore/hms/user/model/User.java`:
```java
import com.fasterxml.jackson.annotation.JsonProperty;
...
@Entity
public class User {
    ...
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Column(nullable = false)
    private String password;
```
* **Why `@JsonProperty(access = JsonProperty.Access.WRITE_ONLY)`:**
  1. **Inbound Deserialization (Write):** Jackson deserializes the incoming plain-text password from JSON request bodies during user registration (`POST /api/auth/register`) and credential submission.
  2. **Outbound Serialization (Read):** When serializing `User` instances to JSON in API responses, Jackson strictly omits the `password` field.

### B. Unit & Integration Testing
* **Unit Test:** Added `user-service/src/test/java/com/medicore/hms/user/model/UserSerializationTest.java`:
  * Validates that serialization of a `User` instance containing a BCrypt hash omits the `"password"` key and value.
  * Validates that deserialization of inbound registration payloads correctly populates the password for hashing by `UserService`.
* **Integration Test Assertions:** Updated `integration-tests/tests/01-users.test.js` to assert `assert.equal(body.password, undefined)` on user creation and retrieval.

---

## 3. Definition of Done (DoD) Verification Matrix

| Acceptance Criteria | Requirement | Status | Verification Mechanism |
| :--- | :--- | :---: | :--- |
| **DoD #1** | Password field annotated `@JsonIgnore` or `@JsonProperty(WRITE_ONLY)` | **PASS** | `User.java` static analysis |
| **DoD #2** | Verified via test that no response body contains password field | **PASS** | `UserSerializationTest.java` (JUnit 5) |
| **DoD #3** | Inbound deserialization allows passwords for register/login | **PASS** | `UserSerializationTest.java` (JUnit 5) |
| **DoD #4** | Existing integration test suite updated with password exclusion assertions | **PASS** | `01-users.test.js` |
| **DoD #5** | Automated verification runner | **PASS** | `scripts/test-password-leak-prevention.sh` (6/6 PASS) |

---

## 4. Verification Execution
```bash
bash scripts/test-password-leak-prevention.sh
```
Result:
```text
==============================================================================
   TITANOPS-108: Password Hash Leak Prevention Verification Suite           
==============================================================================

Phase 1: Static Entity & Annotation Check (DoD #1)
  [PASS] 1. User.java imports com.fasterxml.jackson.annotation.JsonProperty
  [PASS] 2. User.java password field annotated with @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)

Phase 2: Unit Testing & Serialization Boundary (DoD #2)
  [PASS] 3. Automated serialization unit test suite exists (UserSerializationTest.java)
  [PASS] 4. Unit tests passed: Password hash is strictly excluded from serialization
  [PASS] 5. Unit tests passed: Inbound deserialization allows passwords for register/login

Phase 3: Integration Test Assertions (DoD #3)
  [PASS] 6. Integration test suite (01-users.test.js) explicitly asserts password is undefined in API responses

==============================================================================
   Summary: Passed 6/6 tests, Failed: 0
==============================================================================
SUCCESS: All Acceptance Criteria & DoD items for TITANOPS-108 verified!
```
