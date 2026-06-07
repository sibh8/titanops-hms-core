# Use an official OpenJDK runtime as a parent image
FROM eclipse-temurin:11-jre

# Set the working directory in the container
WORKDIR /app

# Download OpenTelemetry Java agent
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.33.6/opentelemetry-javaagent.jar /app/opentelemetry-javaagent.jar

# Copy the executable JAR file from the build context
COPY target/*.jar app.jar

# Make port 8080 available to the world outside this container
EXPOSE 8083

# Run the JAR file with OpenTelemetry agent
ENTRYPOINT ["java","-javaagent:/app/opentelemetry-javaagent.jar","-jar","app.jar"]
