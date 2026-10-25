# Use an official OpenJDK runtime as a parent image
FROM eclipse-temurin:11.0.25_9-jre

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

EXPOSE 8088
ENTRYPOINT ["java","-javaagent:/app/opentelemetry-javaagent.jar","-jar","app.jar"]
