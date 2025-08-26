# ADR-002: Milestone State Selection

## Status
Proposed

## Context

Not all learning states are equal in terms of educational value, maintenance burden, and foundational importance. We need to identify which states should receive priority for maintenance, serve as branching points for other learning paths, and represent the "official" progression path for TraderX.

## Decision

We will establish a **three-tier milestone system** with specific states designated as foundational milestones that receive full maintenance and serve as branching points for specialized learning paths.

### Milestone Tiers:

#### Tier 1: Core Milestones (Full Maintenance)
These represent the primary progression path and receive full maintenance, security updates, and feature enhancements.

1. **milestone/v1.0-baseline** - Current TraderX with Docker Compose
   - Represents starting point for all learning paths
   - Docker Compose deployment
   - Basic monitoring and logging
   - Manual development workflow

2. **milestone/v2.0-modern-devex** - Modern Development Experience
   - Tilt.dev for development automation
   - Enhanced testing and debugging
   - Improved developer productivity
   - Foundation for deployment specialization

3. **milestone/v3.0-production-ready** - Production-Ready System
   - OAuth2 authentication
   - Full observability stack
   - Redis caching
   - PostgreSQL with HA
   - Foundation for advanced features

#### Tier 2: Specialized Milestones (Moderate Maintenance)
These represent important architectural alternatives but are not on the primary progression path.

1. **milestone/v2.1-kubernetes-native** - Kubernetes-First Approach
   - Kubernetes deployment from v1.0
   - Helm charts and operators
   - Service mesh integration
   - Cloud-native patterns

2. **milestone/v2.2-radius-platform** - Platform Engineering Approach
   - Microsoft Radius deployment
   - Application-centric deployment
   - Modern platform abstractions
   - Infrastructure from application perspective

#### Tier 3: Learning Branches (Basic Maintenance)
All other learning states that branch from milestones but don't serve as foundations for other paths.

## Rationale

### Core Milestone Selection Criteria:
1. **Educational Foundation**: Can serve as starting point for multiple learning paths
2. **Architectural Significance**: Represents major architectural decision points
3. **Industry Relevance**: Reflects common real-world evolution patterns
4. **Maintenance Feasibility**: Can be realistically maintained with available resources

### Why These Specific Milestones:

#### v1.0-baseline (Docker Compose)
- **Accessibility**: Easy for developers to understand and run
- **Foundation**: Simple enough to serve as starting point for all tracks
- **Industry Standard**: Docker Compose is widely used for local development
- **Educational Value**: Shows baseline complexity before optimization

#### v2.0-modern-devex (Tilt Development)
- **Developer Productivity**: Demonstrates modern development practices
- **Branching Point**: Natural place to branch into different deployment strategies
- **Learning Value**: Shows impact of development tooling on productivity
- **Industry Trend**: Represents growing focus on developer experience

#### v3.0-production-ready (Full Stack)
- **Real-World Relevance**: Represents production-ready system
- **Integration Point**: Shows how non-functional requirements integrate
- **Advanced Foundation**: Serves as base for advanced functional features
- **Enterprise Ready**: Includes enterprise concerns (auth, observability, performance)

## Alternatives Considered

### Alternative 1: Single Linear Progression
**Rejected**: Doesn't accommodate different architectural approaches or allow for specialization.

### Alternative 2: Many Equal Milestones
**Rejected**: Would spread maintenance effort too thin and confuse learners about recommended paths.

### Alternative 3: Technology-Specific Milestones
**Rejected**: Would lock us into specific technology choices rather than architectural patterns.

## Consequences

### Positive:
- **Clear Priority**: Team knows where to focus maintenance effort
- **Learner Guidance**: Clear recommendations for primary learning path
- **Resource Efficiency**: Concentrates effort on most valuable states
- **Branching Strategy**: Clear foundation states for specialized learning paths

### Negative:
- **Maintenance Inequality**: Some valuable learning states receive less attention
- **Technology Bias**: Milestone choices may favor certain technologies
- **Learning Path Constraints**: May limit exploration of alternative architectures

### Mitigation Strategies:
1. **Regular Review**: Milestone selection reviewed quarterly
2. **Community Input**: Community feedback on milestone relevance
3. **Usage Analytics**: Data-driven decisions on milestone effectiveness
4. **Promotion Path**: Clear criteria for promoting learning states to milestones

## Implementation Plan

### Phase 1: Establish Current Baseline (Month 1)
- Create `milestone/v1.0-baseline` from current main branch
- Document current state capabilities and limitations
- Establish baseline testing and validation

### Phase 2: Modern DevEx Milestone (Months 2-3)
- Implement Tilt.dev development experience
- Create `milestone/v2.0-modern-devex`
- Establish improved development workflows

### Phase 3: Production-Ready Milestone (Months 4-6)
- Integrate authentication, observability, and caching
- Create `milestone/v3.0-production-ready`
- Validate production-readiness

### Phase 4: Specialized Milestones (Months 7-9)
- Create Kubernetes-native and Radius platform milestones
- Validate alternative deployment approaches
- Document architectural trade-offs

## Success Metrics

### Milestone Health:
- **Build Success Rate**: >95% for Tier 1, >90% for Tier 2
- **Security Posture**: All critical CVEs addressed within SLA
- **Documentation Quality**: Complete and current documentation
- **Learning Path Usage**: Analytics on most common progression paths

### Educational Effectiveness:
- **Completion Rates**: Percentage of learners completing milestone-based paths
- **Comprehension**: Assessment of architectural understanding
- **Real-World Application**: Success in applying learnings to other projects

### Maintenance Sustainability:
- **Resource Allocation**: Actual vs. planned maintenance effort
- **Community Contribution**: Level of community support for milestones
- **Technical Debt**: Manageable technical debt across milestones

## Review and Evolution

### Quarterly Reviews:
- Milestone usage and effectiveness analysis
- Community feedback incorporation
- Technology landscape changes assessment
- Resource allocation adjustments

### Annual Assessment:
- Major milestone restructuring consideration
- New milestone candidate evaluation
- Deprecated milestone retirement
- Strategic direction alignment

### Milestone Promotion Criteria:
For a learning state to become a milestone:
1. **High Usage**: >20% of learners follow paths through this state
2. **Foundation Value**: Enables 3+ other learning paths
3. **Maintenance Capacity**: Team can commit to full maintenance
4. **Community Support**: Active community contribution and support
5. **Architectural Significance**: Represents important architectural decision point
