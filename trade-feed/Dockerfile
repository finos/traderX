FROM node:22-alpine
WORKDIR /trade-feed
COPY package*.json ./
RUN npm install --only=production
COPY . .
EXPOSE 18086
CMD [ "node", "index.js" ]