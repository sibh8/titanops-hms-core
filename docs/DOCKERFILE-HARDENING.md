# Dockerfile Hardening & Base Image Pinning (TITANOPS-114)

## Executive Summary
Running containers as the `root` superuser (`UID 0`) presents a critical security vulnerability in cloud and containerized environments. If an attacker discovers a vulnerability or remote code execution (RCE) in an application service running as root, the container boundary provides minimal resistance, enabling container breakout, local host filesystem tampering, or host kernel compromise.

**TITANOPS-114** establishes robust container security across the MediCore Hospital Management System (HMS) by:
1. Enforcing non-root execution across all 10 application containers (Java microservices and frontend NGINX).
2. Pinning immutable base images and exact semantic tags across all Dockerfiles and local development stacks (`docker-compose.yml`), eliminating all ambiguous `:latest` references.
3. Granting minimum required Linux capabilities (`cap_net_bind_service`) for unprivileged processes binding to standard HTTP ports.

---

## Architecture & Hardening Standards

### 1. Java Microservices (Backend)
All 9 Spring Boot microservices utilize Eclipse Temurin OpenJDK runtime:
- **Base Image:** `eclipse-temurin:11.0.25_9-jre` (pinned from `eclipse-temurin:11-jre`)
- **Non-Root Account:** `appuser` (UID: `10001`, GID: `10001`, Group: `appgroup`)
- **Shell & Home:** `/sbin/nologin`, home directory set to `/app`
- **Ownership:** Working directory `/app`, `app.jar`, and OpenTelemetry Java agent are explicitly owned by `10001:10001`.
- **Runtime Directive:** `USER 10001:10001`

```dockerfile
# Use an official OpenJDK runtime as a parent image
FROM eclipse-temurin:11.0.25_9-jre

# Set the working directory in the container
WORKDIR /app

# Create dedicated non-root user and group
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g 10001 -d /app -s /sbin/nologin appuser && \
    chown -R 10001:10001 /app

# Download OpenTelemetry Java agent
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.33.6/opentelemetry-javaagent.jar /app/opentelemetry-javaagent.jar
RUN chmod 644 /app/opentelemetry-javaagent.jar && chown 10001:10001 /app/opentelemetry-javaagent.jar

# Copy the executable JAR file from the build context
COPY --chown=10001:10001 target/*.jar app.jar

# Switch to non-root user
USER 10001:10001

EXPOSE 808x
ENTRYPOINT ["java","-javaagent:/app/opentelemetry-javaagent.jar","-jar","app.jar"]
```

### 2. React / Vite Frontend (NGINX)
The frontend container utilizes a multi-stage build:
- **Build Stage:** `node:20.18-alpine` (pinned from `node:20-alpine`)
- **Serve Stage:** `nginx:1.25.5-alpine` (pinned from `nginx:1.25-alpine`)
- **Non-Root Account:** `nginx` (UID: `101`, GID: `101`)
- **Port 80 Privileged Binding:** By default, Linux reserves ports `< 1024` for root. To allow unprivileged `nginx` to listen on standard port `80` without changing Helm or Docker Compose port mapping contracts, the binary is granted `cap_net_bind_service`:
  ```bash
  apk add --no-cache libcap && setcap 'cap_net_bind_service=+ep' /usr/sbin/nginx
  ```
- **Runtime Path Permissions:**
  - PID file configured to unprivileged `/tmp/nginx.pid`
  - Write permissions granted on `/var/cache/nginx`, `/var/log/nginx`, `/etc/nginx`, and `/tmp`.
- **Runtime Directive:** `USER 101:101`

### 3. Docker Compose Stack Hardening
The observability stack in `docker-compose.yml` previously used `:latest` tags. These have been pinned to verified, stable releases:
- **Jaeger:** `jaegertracing/all-in-one:1.57.0` (pinned from `latest`)
- **OpenTelemetry Collector:** `otel/opentelemetry-collector:0.100.0` (pinned from `latest`)
- **Prometheus:** `prom/prometheus:v2.51.2` (pinned from `latest`)
- **Grafana:** `grafana/grafana:10.4.2` (pinned from `latest`)
- **MySQL:** `mysql:8.0` (remains pinned to stable 8.0 stream)

---

## Automated Verification Suite
To guarantee continuous compliance across all pull requests, an automated test runner is provided at `scripts/verify-dockerfile-hardening.sh` and integrated into `.github/workflows/dockerfile-hardening-ci.yml`:

```bash
# Run local verification suite
./scripts/verify-dockerfile-hardening.sh
```

### Checks Performed:
1. **Static Analysis:**
   - Asserts all 10 Dockerfiles contain `USER` directives with non-zero UID.
   - Asserts `groupadd`, `useradd`, and `/app` ownership commands exist in Java Dockerfiles.
   - Asserts `cap_net_bind_service` and `/tmp/nginx.pid` exist in frontend Dockerfile.
   - Asserts zero `:latest` tags across all Dockerfiles and `docker-compose.yml`.
   - Asserts exact semantic version tags for all base images and compose services.
2. **Runtime Verification:**
   - Builds frontend test image and verifies `whoami` outputs `nginx` and `id -u` outputs `101`.
   - Builds Java test image and verifies `whoami` outputs `appuser` and `id -u` outputs `10001`.
   - Verifies `docker-compose config` parses valid syntax.
