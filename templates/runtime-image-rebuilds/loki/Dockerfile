FROM --platform=$BUILDPLATFORM @@GO_BUILDER_IMAGE@@ AS build
ARG TARGETARCH
ENV GOMEMLIMIT=512MiB GOMAXPROCS=2
RUN apk add --no-cache git
WORKDIR /src
RUN git init && git remote add origin @@SOURCE_REPOSITORY@@ \
 && git config core.sparseCheckout true \
 && printf '/*\n!/vendor/\n' > .git/info/sparse-checkout \
 && git fetch --filter=blob:none --depth=1 origin @@SOURCE_COMMIT@@ && git checkout --detach FETCH_HEAD
ENV GOFLAGS=-mod=mod
RUN --mount=type=cache,target=/go/pkg/mod go get @@GO_DEPENDENCIES@@
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
 CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -p 1 -trimpath -o /out/loki ./cmd/loki
FROM @@BASE_IMAGE@@
COPY --from=build /out/loki /usr/bin/loki
