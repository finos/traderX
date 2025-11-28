FROM --platform=$BUILDPLATFORM eclipse-temurin:21.0.7_6-jdk AS build-stage
WORKDIR /app
COPY . .
# Normalize line endings (remove CR) and ensure the Gradle wrapper is executable
# CRLF line endings or a missing +x bit (from Windows) cause `/bin/sh -c ./gradlew` to fail with exit code 127.
RUN sed -i 's/\r$//' gradlew || true \
	&& chmod +x gradlew \
	&& ./gradlew build --no-daemon --console=plain

FROM eclipse-temurin:21.0.7_6-jre-alpine
RUN mkdir /app
COPY --from=build-stage /app/build/libs/*.jar /app/position-service.jar
EXPOSE 18090
ENTRYPOINT ["java","-jar","/app/position-service.jar"]