FROM eclipse-temurin:21.0.7_6-jdk AS build-stage
WORKDIR /app
COPY . .
RUN ./gradlew build

FROM eclipse-temurin:21.0.7_6-jre-alpine
RUN mkdir /app
COPY --from=build-stage /app/build/libs/*.jar /app/account-service.jar
EXPOSE 18088
ENTRYPOINT ["java","-jar","/app/account-service.jar"]