# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.245.2/containers/java/.devcontainer/base.Dockerfile

# [Choice] Java version (use -bullseye variants on local arm64/Apple Silicon): 11, 17, 11-bullseye, 17-bullseye, 11-buster, 17-buster
FROM node:18

ARG VARIANT="17-bullseye"
FROM mcr.microsoft.com/vscode/devcontainers/java:17

WORKDIR /morphir
COPY . .

EXPOSE 18095


RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y nodejs \
    npm

RUN npm install -g morphir-elm

RUN morphir-elm make
RUN morphir-elm gen
RUN ./gradlew build