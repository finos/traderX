FROM eclipse-temurin:21-jre@sha256:0b99b3376fbb50dbf9c0af8535fdd5b8eb0d3fdfc8b1e4967f383b6919f6901a
# Canonical base OS security refresh
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE 18110
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
