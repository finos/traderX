# Development build for Angular frontend
FROM node:22-bookworm-slim

# Install dependencies and build tools for node-gyp
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy package files and install dependencies
COPY package*.json ./
# Install dependencies using npm install since package-lock.json might not exist
RUN npm install

# Copy all source files including angular.json
COPY . .

EXPOSE 18093
CMD ["npm", "run", "start-prod"]