# Learning Path Architecture

## Technical Implementation Details

### Repository Structure

#### Branch Strategy
```
main (protected, current stable baseline)
├── milestone/v1.0-baseline (current docker-compose state)
├── milestone/v2.0-modern-devex (containerized + tilt)
├── milestone/v3.0-production-ready (auth + observability)
├── milestone/v4.0-advanced (modern features)
├── devex/containerization/docker-compose
├── devex/gitops/tilt-dev
├── devex/deployment/kubernetes
├── devex/deployment/radius
├── nonfunc/auth/oauth2
├── nonfunc/caching/redis
├── nonfunc/observability/opentelemetry
├── nonfunc/database/postgres
├── func/pricing/realtime
├── func/ui/react-modern
└── func/domain/common-model
```

#### State Metadata
Each state branch contains a `.traderx-state.yaml` file:
```yaml
state:
  name: "OAuth2 Authentication"
  track: "nonfunc"
  category: "auth"
  feature: "oauth2"
  milestone: false
  parent_state: "milestone/v1.0-baseline"
  difficulty: "intermediate"
  duration_estimate: "4-6 hours"
  prerequisites:
    - "basic-auth-concepts"
    - "spring-security-familiarity"
  
description: |
  Adds OAuth2 authentication using Auth0 integration.
  Demonstrates modern authentication patterns in microservices.

changes:
  - component: "web-front-end"
    type: "modified"
    description: "Added Auth0 integration"
  - component: "account-service"
    type: "modified"
    description: "JWT validation middleware"
  - component: "trade-service"
    type: "modified"
    description: "Protected endpoints"

learning_objectives:
  - "Understand OAuth2 flow in microservices"
  - "Implement JWT validation"
  - "Secure REST APIs"
  - "Handle authentication state in frontend"

validation:
  tests:
    - "Authentication flow works end-to-end"
    - "Protected endpoints reject unauthenticated requests"
    - "Token refresh works correctly"
  
maintenance:
  last_updated: "2025-08-26"
  next_review: "2025-11-26"
  dependencies_status: "current"
```

### State Management Tooling

#### State Validator Script
```bash
#!/bin/bash
# scripts/validate-state.sh
# Validates that a state is functional and up-to-date

BRANCH=$1
echo "Validating state: $BRANCH"

git checkout $BRANCH
source scripts/setup-environment.sh

# Run all tests
./gradlew test
npm test --prefix reference-data
npm test --prefix trade-feed
dotnet test people-service

# Check for security vulnerabilities
npm audit --prefix reference-data
./gradlew dependencyCheckAnalyze

# Validate docker compose works
docker-compose up -d
sleep 30
curl -f http://localhost:3000/health || exit 1
docker-compose down

echo "State $BRANCH validation: PASSED"
```

#### State Differ Tool
```bash
#!/bin/bash
# scripts/diff-states.sh
# Shows differences between two states

FROM_STATE=$1
TO_STATE=$2

echo "Changes from $FROM_STATE to $TO_STATE:"
git diff $FROM_STATE..$TO_STATE --name-only | while read file; do
  echo "Modified: $file"
done

# Generate learning-focused diff
git diff $FROM_STATE..$TO_STATE --output=diffs/${FROM_STATE}-to-${TO_STATE}.patch
```

### Documentation Generation

#### Automated State Documentation
Each state automatically generates:
1. **Setup Guide**: How to run this specific state
2. **Change Summary**: What's different from parent state
3. **Learning Guide**: Step-by-step tutorial
4. **Reference Documentation**: API changes, configuration updates

#### Learning Path Website
Static site generator creates:
- Interactive state graph
- Guided tutorials for each path
- Search functionality across all states
- Progress tracking for learners

### Testing Strategy

#### Multi-State CI/CD Pipeline
```yaml
# .github/workflows/validate-all-states.yml
name: Validate All States

on:
  schedule:
    - cron: '0 2 * * 1' # Weekly validation
  push:
    branches: [main]

jobs:
  discover-states:
    runs-on: ubuntu-latest
    outputs:
      states: ${{ steps.get-states.outputs.states }}
    steps:
      - uses: actions/checkout@v3
      - id: get-states
        run: |
          git branch -r | grep -E 'origin/(devex|nonfunc|func|milestone)' | \
          sed 's/origin\///' | jq -R -s -c 'split("\n")[:-1]'

  validate-state:
    needs: discover-states
    runs-on: ubuntu-latest
    strategy:
      matrix:
        state: ${{fromJson(needs.discover-states.outputs.states)}}
      fail-fast: false
    steps:
      - uses: actions/checkout@v3
      - name: Validate ${{ matrix.state }}
        run: ./scripts/validate-state.sh ${{ matrix.state }}
```

#### State Health Monitoring
- Automated dependency updates across all milestone states
- Security vulnerability scanning
- Performance regression testing
- Link checking for documentation

### Migration Between States

#### Automated Migration Scripts
For each learning path, provide scripts that:
1. Show what will change
2. Apply changes incrementally
3. Validate each step
4. Roll back if needed

Example:
```bash
# scripts/migrations/baseline-to-oauth2.sh
echo "Migrating from baseline to OAuth2 authentication..."

# Step 1: Add dependencies
echo "Adding Auth0 dependencies..."
# ... specific changes

# Step 2: Update configuration
echo "Updating configuration files..."
# ... specific changes

# Step 3: Validate
echo "Validating migration..."
./scripts/validate-state.sh devex/auth/oauth2
```

### Developer Experience

#### State Switching Tool
```bash
# scripts/switch-state.sh
CURRENT=$(git branch --show-current)
TARGET=$1

echo "Switching from $CURRENT to $TARGET"

# Clean current state
docker-compose down 2>/dev/null || true
./gradlew clean 2>/dev/null || true

# Switch to target
git checkout $TARGET
git pull origin $TARGET

# Setup new state
source scripts/setup-environment.sh
echo "Ready to use state: $TARGET"
echo "Run: ./scripts/start.sh"
```

#### State Comparison Dashboard
Web interface showing:
- Current state health across all branches
- Dependency status
- Test results
- Last update timestamps
- Migration paths available

### Integration Points

#### External Learning Platforms
- Export state metadata for LMS integration
- SCORM package generation for corporate training
- API endpoints for progress tracking

#### IDE Integration
- VS Code extension for state switching
- IntelliJ plugin for guided tutorials
- GitHub Codespaces configuration for each state

## Scalability Considerations

### Performance
- Shallow clones for state switching
- Cached dependencies per state
- Parallel validation across states

### Storage
- Git LFS for large assets
- Automated cleanup of old experimental branches
- Compressed state archives for offline use

### Community Contributions
- Template for creating new states
- Automated validation for PR contributions
- Clear governance for state approval
