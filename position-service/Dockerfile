# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.245.2/containers/java/.devcontainer/base.Dockerfile

# [Choice] Java version (use -bullseye variants on local arm64/Apple Silicon): 11, 17, 11-bullseye, 17-bullseye, 11-buster, 17-buster
ARG VARIANT="21"
FROM mcr.microsoft.com/vscode/devcontainers/java:1-${VARIANT} AS build-stage

# Copy code
WORKDIR /position-service
COPY . .

# Build code
RUN ./gradlew build

FROM mcr.microsoft.com/openjdk/jdk:${VARIANT}-ubuntu
RUN mkdir /app
COPY --from=build-stage /position-service/build/libs/*.jar /app/position-service.jar
EXPOSE 18090
# ENTRYPOINT ./gradlew bootRun
ENTRYPOINT ["java","-jar","/app/position-service.jar"]