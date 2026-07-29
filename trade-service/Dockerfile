FROM eclipse-temurin:21-jre
WORKDIR /opt/app
COPY build/libs/*.jar app.jar
EXPOSE 18092
ENTRYPOINT ["java", "-jar", "/opt/app/app.jar"]
