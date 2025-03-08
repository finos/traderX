FROM --platform=$BUILDPLATFORM node:23 AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --only=production

FROM alpine:3.21
RUN apk add --no-cache nodejs
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY . .
EXPOSE 18086
ENTRYPOINT [ "node", "index.js" ]