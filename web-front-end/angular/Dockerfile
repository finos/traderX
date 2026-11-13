# Development build for Angular frontend
FROM node:22-bookworm-slim@sha256:5ec23b7c622b00547753bc6ffd78085dd868a68aeb41c8e0a1418f033e13d96d

# Install dependencies and build tools for node-gyp
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
# Install dependencies from the committed lockfile
RUN npm ci

# Copy all source files including angular.json
COPY . .

EXPOSE 18093
CMD ["npm", "run", "start-prod"]