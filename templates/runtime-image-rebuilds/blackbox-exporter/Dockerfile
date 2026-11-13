# Rebuild v0.29.1 with the upstream x/net security fix; retain runtime/config layout.
FROM --platform=$BUILDPLATFORM @@GO_BUILDER_IMAGE@@ AS build
ARG TARGETARCH
ENV GOMEMLIMIT=512MiB GOMAXPROCS=2
RUN apk add --no-cache git
WORKDIR /src
RUN git init && git remote add origin @@SOURCE_REPOSITORY@@ \
 && git fetch --depth=1 origin @@SOURCE_COMMIT@@ \
 && git checkout --detach FETCH_HEAD
RUN go get @@GO_DEPENDENCIES@@ && go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -trimpath -o /out/blackbox_exporter .
FROM @@BASE_IMAGE@@
COPY --from=build /out/blackbox_exporter /bin/blackbox_exporter
