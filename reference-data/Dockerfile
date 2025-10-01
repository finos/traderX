FROM node:23 AS builder
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --only=production
RUN npm install @nestjs/cli

COPY . .
RUN npm run build

FROM alpine:3.21
RUN apk add --no-cache nodejs
WORKDIR /usr/src/app
COPY --from=builder /usr/src/app/dist ./dist
COPY --from=builder /usr/src/app/node_modules ./node_modules
COPY . .
EXPOSE 18085
CMD [ "node", "dist/main"]