FROM eclipse-temurin:11-jre
WORKDIR /app
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v1.33.6/opentelemetry-javaagent.jar /app/opentelemetry-javaagent.jar
COPY target/*.jar app.jar
EXPOSE 8088
ENTRYPOINT ["java","-javaagent:/app/opentelemetry-javaagent.jar","-jar","app.jar"]
