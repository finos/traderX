# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.245.2/containers/java/.devcontainer/base.Dockerfile

# [Choice] Java version (use -bullseye variants on local arm64/Apple Silicon): 11, 17, 11-bullseye, 17-bullseye, 11-buster, 17-buster
ARG VARIANT="17-bullseye"
FROM mcr.microsoft.com/vscode/devcontainers/java:0-${VARIANT}

WORKDIR /morphir
COPY . .

EXPOSE 18095

# [Choice] Node.js version: none, lts/*, 18, 16, 14
# ARG NODE_VERSION="18"
# RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1";

RUN ./gradlew build