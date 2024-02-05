# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.245.2/containers/dotnet/.devcontainer/base.Dockerfile

# [Choice] .NET version: 8.0 /8.0-bookworm, 8.0-jammy, 7.0 /7.0-bookworm, 7.0-bullseye, 7.0-jammy, 6.0 /6.0-bookworm, 6.0-bullseye, 6.0-jammy, 6.0-focal
ARG VARIANT="8.0"
FROM mcr.microsoft.com/vscode/devcontainers/dotnet:${VARIANT}

WORKDIR /people-service
COPY . .

EXPOSE 18089

# [Choice] Node.js version: none, lts/*, 18, 16, 14
ARG NODE_VERSION="18"
RUN if [ "${NODE_VERSION}" != "none" ]; then su vscode -c "umask 0002 && . /usr/local/share/nvm/nvm.sh && nvm install ${NODE_VERSION} 2>&1"; fi

# [Optional] Uncomment this section to install additional OS packages.
# RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
#     && apt-get -y install --no-install-recommends <your-package-list-here>

# [Optional] Uncomment this line to install global node packages.
# RUN su vscode -c "source /usr/local/share/nvm/nvm.sh && npm install -g <your-package-here>" 2>&1
ENTRYPOINT cd PeopleService.WebApi && dotnet run