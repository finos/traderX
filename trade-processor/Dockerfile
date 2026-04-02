FROM --platform=$BUILDPLATFORM eclipse-temurin:21.0.10_7-jdk AS build-stage
WORKDIR /app
COPY . .
RUN ./gradlew build

FROM eclipse-temurin:21.0.10_7-jre-alpine
RUN mkdir /app
COPY --from=build-stage /app/build/libs/*.jar /app/trade-processor.jar
EXPOSE 18091
ENTRYPOINT ["java","-jar","/app/trade-processor.jar"]