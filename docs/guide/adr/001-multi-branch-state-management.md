# ADR-001: Multi-Branch State Management

## Status
Proposed

## Context

TraderX needs to evolve from a single reference application into a multi-state learning platform that demonstrates different architectural decisions, deployment strategies, and feature sets. We need to decide how to technically manage these multiple states while maintaining code quality, security, and educational value.

## Decision

We will use a **multi-branch Git repository** approach where each learning state is maintained in its own dedicated branch, with specific commit hashes representing stable learning checkpoints.

### Key Principles:
1. **One Branch Per State**: Each distinct learning state gets its own branch
2. **Immutable Learning Points**: Tagged commits represent stable learning checkpoints
3. **Branch Naming Convention**: `<track>/<category>/<feature>` (e.g., `devex/containerization/docker-compose`)
4. **Milestone Branches**: Special branches marked as foundational states for other learning paths

## Alternatives Considered

### Alternative 1: Multiple Repositories
**Pros**: 
- Complete isolation between states
- Simpler CI/CD per state
- Clear ownership boundaries

**Cons**: 
- Difficult to share common components
- No git history between states
- Complex cross-repository updates
- Higher maintenance overhead
- Harder to visualize learning paths

### Alternative 2: Single Branch with Feature Flags
**Pros**: 
- Single codebase to maintain
- Easier dependency management
- Unified CI/CD

**Cons**: 
- Complex feature flag management
- Code becomes harder to understand
- Difficult to create clean learning experiences
- Deployment complexity increases
- Not suitable for mutually exclusive architectural decisions

### Alternative 3: Git Submodules/Subtrees
**Pros**: 
- Shared components possible
- Individual repository benefits
- Flexible composition

**Cons**: 
- Complex workflow for contributors
- Git submodule learning curve
- Synchronization complexity
- Limited educational value of transitions

## Consequences

### Positive:
- **Clear State Isolation**: Each branch represents a complete, functional state
- **Educational Git History**: Learners can see exactly what changed between states using `git diff`
- **Flexible Branching**: Can create learning paths that branch and merge back
- **Shared Infrastructure**: CI/CD, documentation, and tooling can be shared
- **Natural Versioning**: Git tags provide natural checkpoint versioning

### Negative:
- **Maintenance Complexity**: Need to maintain multiple branches with different codebases
- **Merge Conflicts**: Updates to common components require careful propagation
- **Branch Proliferation**: Risk of having too many branches to maintain effectively
- **Security Updates**: CVE fixes need to be applied across multiple branches

### Mitigation Strategies:
1. **Tiered Maintenance**: Different maintenance levels for different branch types
2. **Automated Tooling**: Scripts for state validation, dependency updates, and branch synchronization
3. **Clear Governance**: Strict criteria for creating new branches and deprecating old ones
4. **Shared Components Strategy**: Identify and manage components that should stay synchronized

## Implementation Details

### Branch Structure:
```
main (current stable state)
milestone/v1.0-baseline
milestone/v2.0-modern-devex
milestone/v3.0-production-ready
devex/containerization/docker-compose
devex/gitops/tilt-dev
devex/deployment/kubernetes
nonfunc/auth/oauth2
nonfunc/caching/redis
func/pricing/realtime
func/ui/react-modern
```

### State Metadata:
Each branch will contain a `.traderx-state.yaml` file defining:
- Parent state relationships
- Learning objectives
- Prerequisites
- Estimated completion time
- Validation criteria

### Tooling Requirements:
- State validation scripts
- Branch synchronization tools
- Automated testing across states
- State comparison utilities
- Learning path visualization

## Success Criteria

1. **Maintainability**: All active states can be kept current and secure with reasonable effort
2. **Educational Value**: Clear progression paths between states with meaningful learning outcomes
3. **Code Quality**: All states maintain high code quality and pass their respective test suites
4. **Security**: Security updates can be efficiently applied across relevant states
5. **Community Adoption**: Contributors can successfully navigate and contribute to the multi-state system

## Review Schedule

This ADR should be reviewed after:
1. **3 months**: Initial implementation experience
2. **6 months**: First complete learning path implementation
3. **12 months**: Community adoption and maintenance burden assessment
