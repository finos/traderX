# Keep PostgreSQL major 16 and the official entrypoint/data layout.
FROM --platform=$BUILDPLATFORM @@GO_BUILDER_IMAGE@@ AS build
ARG TARGETARCH
ENV GOMEMLIMIT=512MiB GOMAXPROCS=2
RUN apk add --no-cache git
WORKDIR /src
RUN git init && git remote add origin @@SOURCE_REPOSITORY@@ \
 && git fetch --depth=1 origin @@SOURCE_COMMIT@@ && git checkout --detach FETCH_HEAD
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -trimpath -o /out/gosu .
FROM @@BASE_IMAGE@@
RUN apk upgrade --no-cache
COPY --from=build /out/gosu /usr/local/bin/gosu
