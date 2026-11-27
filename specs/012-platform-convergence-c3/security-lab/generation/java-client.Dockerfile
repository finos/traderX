FROM eclipse-temurin:21-jre@sha256:0b99b3376fbb50dbf9c0af8535fdd5b8eb0d3fdfc8b1e4967f383b6919f6901a
WORKDIR /opt/app
COPY --chown=10001:10001 app.jar app.jar
USER 10001:10001
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
