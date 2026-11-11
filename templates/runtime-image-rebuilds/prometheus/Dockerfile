# State 009 uses static scrape targets. Omit unused cloud discovery plugins.
FROM --platform=$BUILDPLATFORM golang:1.27.3-alpine AS build
ARG TARGETARCH
ENV GOMEMLIMIT=512MiB GOMAXPROCS=2 GOGC=20
RUN apk add --no-cache git bash
WORKDIR /src
RUN git init && git remote add origin https://github.com/prometheus/prometheus.git \
 && git fetch --depth=1 origin e2e28adeee2c5883d000fc82aca6008cfbf7e96d && git checkout --detach FETCH_HEAD \
 && git fetch --depth=1 origin tag v3.16.0 \
 && test "$(git rev-parse v3.16.0^{commit})" = e2e28adeee2c5883d000fc82aca6008cfbf7e96d
ADD --checksum=sha256:000a45231f6dd22a5703218aad3ee11da125c8a44d1824a27670416c07531001 https://github.com/prometheus/prometheus/releases/download/v3.16.0/prometheus-web-ui-3.16.0.tar.gz /tmp/ui.tar.gz
RUN tar xzf /tmp/ui.tar.gz -C web/ui && scripts/compress_assets.sh
RUN --mount=type=cache,target=/go/pkg/mod go get golang.org/x/net@v0.62.0
RUN --mount=type=cache,target=/go/pkg/mod --mount=type=cache,target=/root/.cache/go-build \
 CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -p 1 -tags builtinassets,remove_all_sd -trimpath -ldflags "-X github.com/prometheus/common/version.Version=3.16.0 -X github.com/prometheus/common/version.Revision=e2e28adeee2c5883d000fc82aca6008cfbf7e96d" -o /out/prometheus ./cmd/prometheus \
 && CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -p 1 -tags remove_all_sd -trimpath -ldflags "-X github.com/prometheus/common/version.Version=3.16.0 -X github.com/prometheus/common/version.Revision=e2e28adeee2c5883d000fc82aca6008cfbf7e96d" -o /out/promtool ./cmd/promtool
FROM prom/prometheus:v3.16.0@sha256:e04987641b57704f408e31f6373ba4138ecf27cb4a165d24aabb6c38fddd0f06
COPY --from=build /out/prometheus /bin/prometheus
COPY --from=build /out/promtool /bin/promtool
