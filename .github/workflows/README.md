# CI/CD Pipeline Documentation

This repository uses GitHub Actions for Continuous Integration and Continuous Deployment.

## Workflows

### 1. CI Workflow (`.github/workflows/ci.yml`)

**Triggers:**
- Push to `main` or `basic-FunctionalityTesting` branches
- Pull requests to `main` branch

**Jobs:**
- **test-java-services**: Runs unit tests for all Java/Gradle services
  - account-service
  - position-service
  - trade-service
  - trade-processor
  
- **test-node-services**: Runs unit tests for all Node.js services
  - reference-data
  - trade-feed (skipped - no tests configured)
  - web-front-end/angular
  - web-front-end/react

- **build**: Builds all applications after tests pass
  - Builds Java services using Gradle
  - Builds Node.js services using npm
  - Builds .NET service using dotnet

**Features:**
- Caches Gradle and npm dependencies for faster builds
- Publishes test results as GitHub check annotations
- Continues on error for services without tests

### 2. Test Workflow (`.github/workflows/test.yml`)

**Triggers:**
- Push to `main` or `basic-FunctionalityTesting` branches
- Pull requests to `main` branch

**Purpose:**
- Standalone test execution workflow
- Can be run independently of the full CI pipeline

### 3. Build and Publish Workflow (`.github/workflows/build-and-publish.yml`)

**Triggers:**
- Manual workflow dispatch
- Push to `main` branch
- After successful CI workflow completion on `main`

**Purpose:**
- Builds Docker images for all services
- Pushes images to GitHub Container Registry (ghcr.io)
- Scans images for vulnerabilities

**Services Built:**
- account-service
- database
- ingress
- people-service
- position-service
- reference-data
- trade-feed
- trade-processor
- trade-service
- web-front-end-angular

### 4. Security Workflow (`.github/workflows/security.yml`)

**Triggers:**
- Manual workflow dispatch
- Scheduled (twice daily on weekdays)
- Push to dependency files

**Purpose:**
- Scans for CVEs in dependencies
- Scans Node.js, .NET, and Gradle projects
- Scans Dockerfiles for vulnerabilities

## Test Coverage

The CI pipeline runs comprehensive test suites including:

- **Account Management Tests**: Get all accounts, get by ID, create, update
- **Account User Management Tests**: Get all mappings, get by account ID, create with validation
- **Trade Service Tests**: Submit trades, validate securities and accounts, buy/sell trades
- **Position Retrieval Tests**: Get all positions, get by account ID
- **Health Check Tests**: Alive and ready endpoints
- **Service Integration Tests**: Trade Service - Account Service integration
- **Error Scenario Tests**: Service unavailable handling

## Running Tests Locally

### Java Services
```bash
cd account-service
./gradlew test
```

### Node.js Services
```bash
cd reference-data
npm test
```

### .NET Service
```bash
cd people-service
dotnet test
```

## Branch Protection

It's recommended to set up branch protection rules for `main`:
- Require status checks to pass before merging
- Require the CI workflow to pass
- Require up-to-date branches before merging

## Workflow Status

You can view workflow runs and their status in the "Actions" tab of the GitHub repository.

