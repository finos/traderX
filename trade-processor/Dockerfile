FROM --platform=$BUILDPLATFORM eclipse-temurin:21.0.7_6-jdk AS build-stage
WORKDIR /app
COPY . .
# Ensure the Gradle wrapper has Unix line endings and is executable.
# On Windows hosts `gradlew` may have CRLF line endings or lack the +x bit,
# which causes `/bin/sh -c ./gradlew` to fail with exit code 127.
RUN sed -i 's/\r$//' gradlew || true \
	&& chmod +x gradlew \
	&& ./gradlew build --no-daemon --console=plain

FROM eclipse-temurin:21.0.7_6-jre-alpine
RUN mkdir /app
COPY --from=build-stage /app/build/libs/*.jar /app/trade-processor.jar
EXPOSE 18091
ENTRYPOINT ["java","-jar","/app/trade-processor.jar"]