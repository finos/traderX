# Keep PostgreSQL major 16 and the official entrypoint/data layout.
FROM --platform=$BUILDPLATFORM golang:1.27.3-alpine AS build
ARG TARGETARCH
ENV GOMEMLIMIT=512MiB GOMAXPROCS=2
RUN apk add --no-cache git
WORKDIR /src
RUN git init && git remote add origin https://github.com/tianon/gosu.git \
 && git fetch --depth=1 origin 29b939aa5bd4dc588af765b8248f6e39150d2565 && git checkout --detach FETCH_HEAD
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH go build -trimpath -o /out/gosu .
FROM postgres:16-alpine@sha256:aa6cb33cf4c19c765cefcf48d96176258800870a9a1e930ad126200f9d825139
RUN apk upgrade --no-cache
COPY --from=build /out/gosu /usr/local/bin/gosu
