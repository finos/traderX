FROM eclipse-temurin:21.0.7_6-jdk AS build-stage
WORKDIR /app
COPY . .
RUN ./gradlew build

FROM eclipse-temurin:21.0.7_6-jre-alpine
RUN mkdir /app
COPY --from=build-stage /app/build/libs/*.jar /app/position-service.jar
EXPOSE 18090
ENTRYPOINT ["java","-jar","/app/position-service.jar"]