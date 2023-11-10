
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

RUN ./gradlew build