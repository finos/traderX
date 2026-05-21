FROM eclipse-temurin:21.0.11_10-jre
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE 18088
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
