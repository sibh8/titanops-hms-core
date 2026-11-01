# Use an official OpenJDK runtime as a parent image
FROM eclipse-temurin:11.0.25_9-jre

# Set the working directory in the container
WORKDIR /app

# Create dedicated non-root user and group
RUN groupadd -g 10001 appgroup && \
    useradd -u 10001 -g 10001 -d /app -s /sbin/nologin appuser && \
    chown -R 10001:10001 /app

# Download OpenTelemetry Java agent at build time
ARG OTEL_AGENT_VERSION=2.33.1
RUN set -eux; \
    curl -fsSL --retry 3 --retry-delay 2 \
      -o /app/opentelemetry-javaagent.jar \
      "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${OTEL_AGENT_VERSION}/opentelemetry-javaagent.jar"; \
    chmod 644 /app/opentelemetry-javaagent.jar; \
    chown 10001:10001 /app/opentelemetry-javaagent.jar

# Copy the executable JAR file from the build context
COPY --chown=10001:10001 target/*.jar app.jar

# Switch to non-root user
USER 10001:10001

# Make port 8083 available to the world outside this container
EXPOSE 8083

# Run the JAR file with OpenTelemetry agent
ENTRYPOINT ["java","-javaagent:/app/opentelemetry-javaagent.jar","-jar","app.jar"]
