# Generated runtimes use static scrape targets; omit unused cloud discovery plugins.
FROM --platform=$BUILDPLATFORM @@GO_BUILDER_IMAGE@@ AS build
ARG TARGETARCH
ENV GOMEMLIMIT=512MiB GOMAXPROCS=2 GOGC=20
RUN apk add --no-cache git bash
WORKDIR /src
RUN git init && git remote add origin @@SOURCE_REPOSITORY@@ \
 && git fetch --depth=1 origin @@SOURCE_COMMIT@@ && git checkout --detach FETCH_HEAD \
 && git fetch --depth=1 origin tag @@SOURCE_TAG@@ \
 && test "$(git rev-parse @@SOURCE_TAG@@^{commit})" = @@SOURCE_COMMIT@@
ADD --checksum=sha256:@@UI_ARCHIVE_SHA256@@ @@UI_ARCHIVE@@ /tmp/ui.tar.gz
RUN tar xzf /tmp/ui.tar.gz -C web/ui && scripts/compress_assets.sh
RUN --mount=type=cache,target=/go/pkg/mod go get @@GO_DEPENDENCIES@@
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
 CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -p 1 -tags builtinassets,remove_all_sd -trimpath -ldflags "-X github.com/prometheus/common/version.Version=@@VERSION@@ -X github.com/prometheus/common/version.Revision=@@SOURCE_COMMIT@@" -o /out/prometheus ./cmd/prometheus \
 && CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -p 1 -tags remove_all_sd -trimpath -ldflags "-X github.com/prometheus/common/version.Version=@@VERSION@@ -X github.com/prometheus/common/version.Revision=@@SOURCE_COMMIT@@" -o /out/promtool ./cmd/promtool
FROM @@BASE_IMAGE@@
COPY --from=build /out/prometheus /bin/prometheus
COPY --from=build /out/promtool /bin/promtool
