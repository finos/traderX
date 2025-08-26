# ADR-004: Testing Strategy Across States

## Status
Proposed

## Context

With multiple learning states maintained in parallel branches, we need a comprehensive testing strategy that ensures:
- All states remain functional and secure
- Learning paths work as documented
- State transitions are smooth and educational
- Maintenance burden remains manageable
- Different states can have different testing requirements

The testing strategy must balance thoroughness with resource constraints while providing confidence in the educational experience.

## Decision

We will implement a **tiered testing strategy** that matches our state maintenance tiers, with shared testing infrastructure and state-specific test suites.

### Testing Tiers Aligned with State Tiers:

#### Tier 1 (Milestone States): Comprehensive Testing
- **Unit Tests**: Full coverage of business logic
- **Integration Tests**: All service interactions
- **End-to-End Tests**: Complete user workflows
- **Performance Tests**: Baseline performance metrics
- **Security Tests**: Comprehensive security scanning
- **Accessibility Tests**: Basic accessibility compliance
- **Migration Tests**: Smooth transitions between states

#### Tier 2 (Active Learning Paths): Focused Testing
- **Unit Tests**: Core business logic only
- **Integration Tests**: Critical service interactions
- **Smoke Tests**: Basic functionality validation
- **Security Tests**: Vulnerability scanning
- **Migration Tests**: Transition to/from parent states

#### Tier 3 (Experimental States): Minimal Testing
- **Smoke Tests**: Application starts and basic endpoints respond
- **Security Tests**: Critical vulnerability scanning only
- **Basic Migration Tests**: Can be reached from parent state

### Shared Testing Infrastructure:

#### Common Test Utilities
```
tests/
├── common/
│   ├── fixtures/            # Shared test data
│   ├── utilities/           # Helper functions
│   ├── assertions/          # Custom assertions
│   └── setup/              # Environment setup
├── state-specific/
│   ├── milestone-v1/        # State-specific tests
│   ├── milestone-v2/
│   └── ...
├── migration/
│   ├── baseline-to-oauth/   # Migration tests
│   ├── oauth-to-prod/
│   └── ...
└── cross-state/
    ├── api-compatibility/   # API consistency tests
    └── data-consistency/    # Data format consistency
```

## Implementation Details

### 1. Automated Testing Pipeline

#### Multi-State Validation Workflow
```yaml
# .github/workflows/multi-state-validation.yml
name: Multi-State Validation

on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly full validation
  push:
    branches: [main]
  pull_request:
    branches: ['milestone/*']

jobs:
  discover-states:
    runs-on: ubuntu-latest
    outputs:
      tier1-states: ${{ steps.get-states.outputs.tier1 }}
      tier2-states: ${{ steps.get-states.outputs.tier2 }}
      tier3-states: ${{ steps.get-states.outputs.tier3 }}
    steps:
      - uses: actions/checkout@v3
      - name: Discover States by Tier
        id: get-states
        run: ./scripts/discover-states-by-tier.sh

  tier1-comprehensive:
    needs: discover-states
    runs-on: ubuntu-latest
    strategy:
      matrix:
        state: ${{fromJson(needs.discover-states.outputs.tier1-states)}}
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ matrix.state }}
      - name: Run Comprehensive Test Suite
        run: ./scripts/test-tier1.sh

  tier2-focused:
    needs: discover-states
    runs-on: ubuntu-latest
    strategy:
      matrix:
        state: ${{fromJson(needs.discover-states.outputs.tier2-states)}}
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ matrix.state }}
      - name: Run Focused Test Suite
        run: ./scripts/test-tier2.sh

  tier3-smoke:
    needs: discover-states
    runs-on: ubuntu-latest
    strategy:
      matrix:
        state: ${{fromJson(needs.discover-states.outputs.tier3-states)}}
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ matrix.state }}
      - name: Run Smoke Tests
        run: ./scripts/test-tier3.sh
```

### 2. State-Specific Test Suites

#### Tier 1 Test Script Example
```bash
#!/bin/bash
# scripts/test-tier1.sh
# Comprehensive testing for milestone states

set -e

echo "Running Tier 1 comprehensive tests for: $(git branch --show-current)"

# 1. Unit Tests
echo "Running unit tests..."
./gradlew test
npm test --prefix reference-data
npm test --prefix trade-feed
dotnet test people-service

# 2. Integration Tests
echo "Running integration tests..."
docker-compose -f docker-compose.test.yml up -d
sleep 30
./scripts/run-integration-tests.sh
docker-compose -f docker-compose.test.yml down

# 3. End-to-End Tests
echo "Running E2E tests..."
docker-compose up -d
sleep 60
npm run test:e2e --prefix web-front-end
docker-compose down

# 4. Performance Tests
echo "Running performance tests..."
./scripts/run-performance-tests.sh

# 5. Security Tests
echo "Running security tests..."
npm audit --audit-level moderate
./gradlew dependencyCheckAnalyze
./scripts/run-security-scan.sh

# 6. Accessibility Tests
echo "Running accessibility tests..."
npm run test:a11y --prefix web-front-end

echo "All Tier 1 tests passed!"
```

#### Tier 2 Test Script Example
```bash
#!/bin/bash
# scripts/test-tier2.sh
# Focused testing for active learning paths

set -e

echo "Running Tier 2 focused tests for: $(git branch --show-current)"

# 1. Core Unit Tests
echo "Running core unit tests..."
./gradlew test --tests="*core*"
npm test --prefix reference-data --grep="core"

# 2. Critical Integration Tests
echo "Running critical integration tests..."
docker-compose -f docker-compose.test.yml up -d
sleep 30
./scripts/run-critical-integration-tests.sh
docker-compose -f docker-compose.test.yml down

# 3. Smoke Tests
echo "Running smoke tests..."
./scripts/run-smoke-tests.sh

# 4. Security Scan
echo "Running security scan..."
npm audit --audit-level high
./gradlew dependencyCheckAnalyze --failOnError

echo "All Tier 2 tests passed!"
```

### 3. Migration Testing

#### State Transition Validation
```bash
#!/bin/bash
# scripts/test-migration.sh
# Tests migration from one state to another

FROM_STATE=$1
TO_STATE=$2

echo "Testing migration from $FROM_STATE to $TO_STATE"

# 1. Start with source state
git checkout $FROM_STATE
./scripts/validate-state.sh $FROM_STATE

# 2. Apply migration
./scripts/migrate-state.sh $FROM_STATE $TO_STATE

# 3. Validate target state
./scripts/validate-state.sh $TO_STATE

# 4. Test that learning objectives are met
./scripts/validate-learning-objectives.sh $TO_STATE

echo "Migration test passed!"
```

#### Learning Path Validation
```bash
#!/bin/bash
# scripts/test-learning-path.sh
# Tests complete learning path

LEARNING_PATH=$1  # e.g., "devex-containerization-path"

# Read learning path definition
source ./learning-paths/$LEARNING_PATH.sh

echo "Testing learning path: $LEARNING_PATH"

for i in "${!STATES[@]}"; do
  if [ $i -eq 0 ]; then
    # First state - validate directly
    git checkout ${STATES[$i]}
    ./scripts/validate-state.sh ${STATES[$i]}
  else
    # Subsequent states - test migration
    ./scripts/test-migration.sh ${STATES[$((i-1))]} ${STATES[$i]}
  fi
done

echo "Learning path test completed successfully!"
```

### 4. Cross-State Consistency Testing

#### API Compatibility Tests
```javascript
// tests/cross-state/api-compatibility.test.js
describe('API Compatibility Across States', () => {
  const states = ['milestone/v1.0-baseline', 'milestone/v2.0-modern-devex'];
  
  states.forEach(state => {
    describe(`API compatibility for ${state}`, () => {
      test('Account service API contract maintained', async () => {
        // Test that core API contracts remain stable
        const response = await fetch('/api/accounts');
        expect(response.status).toBe(200);
        
        const data = await response.json();
        expect(data).toHaveProperty('accounts');
        expect(Array.isArray(data.accounts)).toBe(true);
      });
    });
  });
});
```

#### Data Format Consistency
```javascript
// tests/cross-state/data-consistency.test.js
describe('Data Format Consistency', () => {
  test('Trade data structure remains consistent', () => {
    const tradeSchemas = {
      'milestone/v1.0-baseline': require('./schemas/trade-v1.json'),
      'milestone/v2.0-modern-devex': require('./schemas/trade-v2.json')
    };
    
    // Validate that core fields remain consistent
    Object.keys(tradeSchemas).forEach(state => {
      const schema = tradeSchemas[state];
      expect(schema.properties).toHaveProperty('tradeId');
      expect(schema.properties).toHaveProperty('accountId');
      expect(schema.properties).toHaveProperty('symbol');
    });
  });
});
```

## Test Data Management

### Shared Test Datasets
```yaml
# tests/common/test-data.yaml
accounts:
  - id: "ACC001"
    name: "Test Account 1"
    balance: 100000
  - id: "ACC002"
    name: "Test Account 2"
    balance: 50000

trades:
  - tradeId: "TRD001"
    accountId: "ACC001"
    symbol: "AAPL"
    quantity: 100
    price: 150.00

reference_data:
  symbols:
    - symbol: "AAPL"
      name: "Apple Inc."
      exchange: "NASDAQ"
```

### State-Specific Test Data
```yaml
# tests/state-specific/oauth-state/test-data.yaml
# Additional test data for OAuth-enabled states
auth_tokens:
  - user: "testuser1"
    token: "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
    expires: "2024-12-31T23:59:59Z"

protected_endpoints:
  - path: "/api/trades"
    method: "POST"
    requires_auth: true
```

## Performance Testing Strategy

### Baseline Performance Metrics
Each state maintains baseline performance expectations:

```yaml
# .traderx-performance.yaml
performance_baselines:
  api_response_times:
    accounts_list: "< 200ms"
    trade_submission: "< 500ms"
    position_lookup: "< 300ms"
  
  throughput:
    concurrent_users: 50
    trades_per_second: 10
  
  resource_usage:
    memory_limit: "512MB"
    cpu_limit: "1 core"
```

### Performance Regression Detection
```bash
#!/bin/bash
# scripts/performance-test.sh
# Detects performance regressions

STATE=$(git branch --show-current)
BASELINE_FILE=".traderx-performance.yaml"

echo "Running performance tests for $STATE"

# Start application
docker-compose up -d
sleep 60

# Run performance tests
k6 run --out json=performance-results.json tests/performance/load-test.js

# Compare with baseline
python scripts/compare-performance.py performance-results.json $BASELINE_FILE

# Alert if regression detected
if [ $? -ne 0 ]; then
  echo "Performance regression detected!"
  exit 1
fi
```

## Security Testing Framework

### Automated Security Scanning
```yaml
# .github/workflows/security-scan.yml
security_scans:
  dependency_check:
    tools: ["npm audit", "gradlew dependencyCheckAnalyze", "dotnet list package --vulnerable"]
    schedule: "daily"
    
  container_scan:
    tools: ["trivy", "snyk container"]
    schedule: "weekly"
    
  code_analysis:
    tools: ["CodeQL", "SonarQube"]
    schedule: "on_push"
    
  web_security:
    tools: ["OWASP ZAP", "Nuclei"]
    schedule: "weekly"
```

## Educational Testing

### Learning Objective Validation
```bash
#!/bin/bash
# scripts/validate-learning-objectives.sh
# Validates that learning objectives are met

STATE=$1
OBJECTIVES_FILE="learning-objectives/$STATE.yaml"

echo "Validating learning objectives for $STATE"

# Parse learning objectives
objectives=$(yq eval '.learning_objectives[]' $OBJECTIVES_FILE)

for objective in $objectives; do
  echo "Testing objective: $objective"
  
  # Run objective-specific tests
  ./tests/learning-objectives/test-$objective.sh
  
  if [ $? -eq 0 ]; then
    echo "✓ $objective - PASSED"
  else
    echo "✗ $objective - FAILED"
    exit 1
  fi
done

echo "All learning objectives validated successfully!"
```

## Monitoring and Reporting

### Test Result Dashboard
- State health overview
- Test success rates by tier
- Performance trend analysis
- Security posture tracking
- Learning path success rates

### Automated Reporting
```bash
#!/bin/bash
# scripts/generate-test-report.sh
# Generates comprehensive test report

echo "Generating multi-state test report..."

# Collect test results from all states
./scripts/collect-test-results.sh

# Generate HTML report
python scripts/generate-report.py \
  --results test-results/ \
  --output reports/weekly-test-report.html \
  --template templates/test-report.html

# Send to stakeholders
./scripts/send-report.sh reports/weekly-test-report.html
```

## Resource Optimization

### Parallel Test Execution
- Tests for different states run in parallel
- Resource pooling for common infrastructure
- Cached dependencies and test artifacts
- Smart test scheduling based on state importance

### Test Environment Management
- Containerized test environments
- Resource isolation between state tests
- Cleanup automation
- Cost optimization for cloud resources

## Success Metrics

### Test Effectiveness:
- **Coverage**: Percentage of code covered by tests per state tier
- **Reliability**: Test stability and false positive rates
- **Speed**: Test execution time and feedback loop speed
- **Detection**: Time to detect and report issues

### Educational Validation:
- **Learning Success**: Percentage of learners completing paths successfully
- **Objective Achievement**: Assessment of learning objective completion
- **Path Stability**: How often learning paths are broken by changes
- **Migration Success**: Success rate of state transitions

This testing strategy ensures that all learning states remain functional and educational while managing testing complexity and resource requirements effectively.
