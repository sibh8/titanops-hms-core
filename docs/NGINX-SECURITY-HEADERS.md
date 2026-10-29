# Hardened Nginx and Ingress Security Response Headers
**Ticket Reference:** `TITANOPS-130`  
**Author:** Siddhesh Bhandarkar (`sibh8`) / Platform Engineering  
**Locations:** `frontend/nginx.conf`, `k8s/ingress/01-alb-ingress-tls.yaml`

---

## 1. Executive Summary

Prior to `TITANOPS-130`, the frontend Nginx reverse proxy emitted baseline headers (`X-Frame-Options`, `X-Content-Type-Options`, and `X-XSS-Protection`), but lacked modern web application defenses against clickjacking, unauthorized browser feature invocation, insecure transport downgrades, and cross-site scripting (XSS).

This ticket implements and hardens:
1. `Content-Security-Policy` (CSP)
2. `Strict-Transport-Security` (HSTS)
3. `Referrer-Policy`
4. `Permissions-Policy`

Both at the **Ingress layer** (ALB custom response headers) and at the **Nginx container layer** (`frontend/nginx.conf`).

---

## 2. Hardened Headers Overview

| Header | Configured Value | Security Impact |
| :--- | :--- | :--- |
| **`Content-Security-Policy`** | `default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com data:; img-src 'self' data: https:; connect-src 'self' http: https:; frame-ancestors 'self';` | Blocks unauthorized script execution and restricted origin connections while preserving Vite SPA bundle and Google Font styling. |
| **`Strict-Transport-Security`** | `max-age=31536000; includeSubDomains; preload` | Forces client browsers to connect strictly over HTTPS for at least 1 year and allows HSTS preload list eligibility. |
| **`Referrer-Policy`** | `strict-origin-when-cross-origin` | Strips path and query information when navigating across origins to prevent accidental leak of patient tokens or URLs. |
| **`Permissions-Policy`** | `camera=(), microphone=(), geolocation=(), payment=()` | Disables sensitive browser hardware APIs and sensor queries. |
| **`X-Frame-Options`** | `SAMEORIGIN` | Mitigates UI redress / clickjacking attacks. |
| **`X-Content-Type-Options`** | `nosniff` | Disables MIME type sniffing by client browsers. |
| **`X-XSS-Protection`** | `1; mode=block` | Legacy XSS filter activation for older browser clients. |

---

## 3. Implementation Details

1. **`frontend/nginx.conf`**:
   - Headers defined in `server` block with `always` parameter to ensure headers are sent on error status codes (4xx/5xx).
   - Re-applied in `location /` and `location /assets/` to prevent Nginx's default behavior where location-level `add_header` overrides parent headers.
2. **`k8s/ingress/01-alb-ingress-tls.yaml`**:
   - Configured via `alb.ingress.kubernetes.io/custom-response-headers` so that ALB edge listeners enforce these headers before traffic touches pods.

---

## 4. Verification

The verification script `scripts/test-nginx-security-headers.sh` performs:
- Configuration audit of `frontend/nginx.conf` for all 7 headers.
- YAML parsing and annotation verification of `01-alb-ingress-tls.yaml`.
- Live HTTP server execution inspecting client response headers.
- CSP compatibility validation with Vite SPA build requirements and external fonts.

Execution:
```bash
./scripts/test-nginx-security-headers.sh
```
All 9 verification tests pass.
