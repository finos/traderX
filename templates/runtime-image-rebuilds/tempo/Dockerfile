FROM --platform=$BUILDPLATFORM golang:1.27.3-alpine AS build
ARG TARGETARCH
ENV GOMEMLIMIT=512MiB GOMAXPROCS=2
RUN apk add --no-cache git
WORKDIR /src
RUN git init && git remote add origin https://github.com/grafana/tempo.git \
 && git config core.sparseCheckout true \
 && printf '/*\n!/vendor/\n' > .git/info/sparse-checkout \
 && git fetch --filter=blob:none --depth=1 origin 9db7df79d2af105a90d96484e6403e1fda0d011e && git checkout --detach FETCH_HEAD
ENV GOFLAGS=-mod=mod
RUN --mount=type=cache,target=/go/pkg/mod go get golang.org/x/net@v0.62.0 github.com/go-jose/go-jose/v4@v4.1.6
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
 CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -p 1 -trimpath -o /out/tempo ./cmd/tempo
FROM grafana/tempo:3.1.1@sha256:64e2fbd56d9c2b3412a4b430a58ea59e91a670b1e75f920a0c702213ad145044
COPY --from=build /out/tempo /tempo
