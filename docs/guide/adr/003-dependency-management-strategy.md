# ADR-003: Dependency Management Strategy

## Status
Proposed

## Context

Managing dependencies across multiple learning states presents unique challenges:
- **Security Updates**: CVEs must be addressed across all active states
- **Version Drift**: Different states may require different dependency versions
- **Update Propagation**: Changes to common dependencies need coordinated updates
- **Testing Burden**: Each state needs validation after dependency updates
- **Compatibility**: Some learning states may be incompatible with latest versions

We need a strategy that balances security, maintainability, and educational value while keeping the maintenance burden manageable.

## Decision

We will implement a **tiered dependency management strategy** with automated tooling for updates and validation, combined with shared dependency matrices for common components.

### Core Strategy:

#### 1. Dependency Classification
- **Critical Security Dependencies**: Runtime libraries, web frameworks, database drivers
- **Development Dependencies**: Build tools, testing frameworks, linting tools
- **Educational Dependencies**: Libraries specific to learning objectives
- **Platform Dependencies**: Container base images, runtime environments

#### 2. Update Strategies by State Tier

##### Tier 1 (Milestone States):
- **Security Updates**: Automated with 24-48 hour SLA
- **Minor Updates**: Monthly batch with automated testing
- **Major Updates**: Quarterly with manual review
- **Breaking Changes**: Coordinated updates across all Tier 1 states

##### Tier 2 (Active Learning Paths):
- **Security Updates**: Automated with 1-week SLA
- **Minor Updates**: Quarterly batch
- **Major Updates**: Only if required for security
- **Breaking Changes**: Only if absolutely necessary

##### Tier 3 (Experimental States):
- **Security Updates**: Critical only, monthly batch
- **Minor Updates**: Annual or as-needed
- **Major Updates**: Only for critical security issues
- **Breaking Changes**: Acceptable; may lead to deprecation

#### 3. Shared Dependency Matrix
Common dependencies tracked centrally with state-specific compatibility:

```yaml
# .traderx-dependencies.yaml
shared_dependencies:
  spring_boot:
    current_version: "3.2.0"
    security_baseline: "3.1.5"
    compatible_states:
      milestone/v1.0-baseline: "3.1.8"
      milestone/v2.0-modern-devex: "3.2.0"
      milestone/v3.0-production-ready: "3.2.0"
      devex/containerization/docker-compose: "3.1.8"
      
  nodejs:
    current_version: "20.10.0"
    security_baseline: "18.19.0"
    compatible_states:
      ALL: "20.10.0"  # Node.js update is generally safe
      
  postgresql_driver:
    current_version: "42.7.1"
    security_baseline: "42.6.0"
    compatible_states:
      states_with_postgres: "42.7.1"
      states_with_h2: "N/A"
```

## Implementation Details

### 1. Automated Dependency Scanning

#### Daily Security Scanning
```yaml
# .github/workflows/security-scan.yml
name: Multi-State Security Scan
on:
  schedule:
    - cron: '0 6 * * *'  # Daily at 6 AM UTC

jobs:
  security-scan:
    strategy:
      matrix:
        branch: ${{ fromJSON(needs.get-active-branches.outputs.branches) }}
    steps:
      - uses: actions/checkout@v3
        with:
          ref: ${{ matrix.branch }}
      - name: Run Security Scan
        run: |
          npm audit --audit-level high
          ./gradlew dependencyCheckAnalyze
          dotnet list package --vulnerable
```

#### Dependency Update Bot
```yaml
# .github/dependabot.yml
version: 2
updates:
  # Tier 1 states - frequent updates
  - package-ecosystem: "gradle"
    directory: "/"
    schedule:
      interval: "daily"
    target-branch: "milestone/v1.0-baseline"
    
  - package-ecosystem: "npm"
    directory: "/reference-data"
    schedule:
      interval: "daily"
    target-branch: "milestone/v1.0-baseline"
    
  # Tier 2 states - weekly updates
  - package-ecosystem: "gradle"
    directory: "/"
    schedule:
      interval: "weekly"
    target-branch: "devex/containerization/docker-compose"
```

### 2. Shared Component Synchronization

#### Common Component Identification
```bash
# scripts/identify-common-components.sh
# Identifies files that should stay synchronized across states

common_files=(
  "database/initialSchema.sql"
  "docs/c4/c4-diagram.dsl"
  "gradle/wrapper/gradle-wrapper.properties"
  # Add more common files
)

for file in "${common_files[@]}"; do
  echo "Tracking: $file"
  # Add to synchronization matrix
done
```

#### Synchronized Update Process
```bash
# scripts/sync-common-updates.sh
# Propagates common component updates across states

SOURCE_BRANCH="main"
TARGET_BRANCHES=("milestone/v1.0-baseline" "milestone/v2.0-modern-devex")

for branch in "${TARGET_BRANCHES[@]}"; do
  git checkout $branch
  git cherry-pick --no-commit $COMMON_UPDATE_COMMIT
  # Resolve conflicts if any
  git commit -m "Sync: $(git log --oneline -1 $COMMON_UPDATE_COMMIT)"
done
```

### 3. Dependency Update Workflow

#### Tier 1 (Milestone) Update Process:
1. **Automated PR Creation**: Dependabot creates update PR
2. **Security Validation**: Automated security scan validates improvement
3. **Automated Testing**: Full test suite runs on PR
4. **Cross-State Impact Analysis**: Check if update affects other states
5. **Auto-merge or Manual Review**: Based on change significance
6. **Propagation Planning**: Schedule updates for dependent states

#### Tier 2/3 Update Process:
1. **Batch Collection**: Security updates collected for batch processing
2. **Impact Assessment**: Determine which states need updates
3. **Automated Testing**: Basic functionality validation
4. **Manual Review**: Security-focused review
5. **Conditional Merge**: Merge only if tests pass

### 4. Breaking Change Management

#### Breaking Change Protocol:
1. **Impact Assessment**: Identify all affected states
2. **Migration Strategy**: Create state-specific migration guides
3. **Coordinated Timeline**: Plan updates across all affected states
4. **Rollback Preparation**: Ensure rollback capability
5. **Documentation**: Update learning materials

#### Example: Spring Boot 3.x Migration
```yaml
# Breaking change management plan
change: "Spring Boot 2.x to 3.x migration"
impact_assessment:
  affected_states:
    - milestone/v1.0-baseline
    - milestone/v2.0-modern-devex
    - milestone/v3.0-production-ready
    - devex/containerization/docker-compose
    - nonfunc/auth/oauth2
  
migration_strategy:
  phase_1: "Update milestone states first"
  phase_2: "Update high-priority learning states"
  phase_3: "Update or deprecate experimental states"
  
timeline:
  planning: "2 weeks"
  implementation: "4 weeks"
  validation: "2 weeks"
  
rollback_plan:
  trigger_criteria: ">2 failing states in Tier 1"
  rollback_procedure: "Revert all changes, investigate issues"
```

## Alternative Approaches Considered

### Alternative 1: Pinned Versions Across All States
**Pros**: Consistent dependency versions, predictable behavior
**Cons**: Security vulnerabilities persist longer, inhibits learning about version differences
**Rejected**: Too restrictive for educational purposes

### Alternative 2: Independent Dependency Management Per State
**Pros**: Maximum flexibility per state
**Cons**: Massive maintenance burden, security update complexity
**Rejected**: Unsustainable maintenance overhead

### Alternative 3: Automatic Updates Without Tiers
**Pros**: Always current dependencies
**Cons**: High risk of breaking learning states, no prioritization
**Rejected**: Too risky for educational platform stability

## Benefits and Trade-offs

### Benefits:
- **Security**: Systematic approach to security updates
- **Maintainability**: Automated tooling reduces manual effort
- **Educational Value**: Shows real-world dependency management challenges
- **Flexibility**: Different update cadences for different state importance

### Trade-offs:
- **Complexity**: Sophisticated tooling and process required
- **Resource Intensive**: Still requires significant automation infrastructure
- **Version Skew**: Different states may have different dependency versions
- **Learning Curve**: Contributors need to understand the dependency strategy

## Success Metrics

### Security Metrics:
- **CVE Response Time**: Time from CVE publication to fix deployment
- **Vulnerability Count**: Number of known vulnerabilities across all states
- **Security Score**: Automated security scoring across states

### Maintenance Metrics:
- **Update Success Rate**: Percentage of automated updates that succeed
- **Manual Intervention Rate**: How often manual intervention is required
- **Time to Update**: Average time to update dependencies across states

### Educational Metrics:
- **Learning Path Stability**: How often dependency issues break learning paths
- **Version Diversity**: Appropriate variety in dependency versions for learning
- **Real-world Relevance**: How well dependency choices reflect industry practices

## Implementation Timeline

### Month 1: Foundation
- Set up dependency scanning infrastructure
- Create shared dependency matrix
- Implement basic automation

### Month 2: Tier 1 Automation
- Full automation for milestone states
- Automated testing and validation
- Security update workflows

### Month 3: Cross-State Coordination
- Synchronization tooling for common components
- Breaking change management process
- Documentation and training

### Month 4+: Optimization
- Refine automation based on experience
- Add more sophisticated analysis
- Community training and contribution guidelines

## Review and Evolution

This dependency management strategy should be reviewed:
- **Monthly**: Effectiveness and pain points
- **Quarterly**: Automation improvements and process refinement
- **Annually**: Strategic approach and tool evaluation

The strategy should evolve based on:
- Community feedback on maintenance burden
- Security landscape changes
- New dependency management tools and practices
- Learning platform usage patterns
