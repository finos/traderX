FROM clojure:temurin-21-tools-deps-jammy AS builder
RUN mkdir -p /build
WORKDIR /build
ADD ./deps.edn /build/deps.edn
RUN clj -P
COPY ./ /build

FROM clojure:temurin-21-tools-deps-jammy AS final
ENV USER=nonroot
ENV GROUPNAME=$USER
ENV UID=1000
ENV GID=1000
RUN addgroup \
    --gid "$GID" \
    "$GROUPNAME" \
    &&  adduser \
    --disabled-password \
    --gecos "" \
    --home "$(pwd)" \
    --ingroup "$GROUPNAME" \
    --no-create-home \
    --uid "$UID" \
    $USER

RUN apt-get update && \
    apt-get install -yq  \
    dumb-init \
    curl \
    telnet \
    netcat

RUN mkdir -p /service
WORKDIR /service
EXPOSE 18085
ENV ENV=dev
ENV PORT=3000
ENV BOOTSTRAP_SERVERS=localhost:9092
ENV TENANT=multi
USER $USER
COPY --from=builder --chown=$USER:$GROUPNAME /build /service
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["clj","-J-XX:+UseContainerSupport","-J-XX:MaxRAMPercentage=85","-J-XX:+UnlockExperimentalVMOptions","-J-XX:+UseZGC","-M","-m","price-service.price-service"]
