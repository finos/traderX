# TraderX Learning Path Strategy

This directory contains the strategy and planning documentation for implementing a multi-state learning path system for the TraderX project.

## Overview

TraderX is being transformed into an educational platform that demonstrates multiple evolutionary states of a trading application, each representing different architectural decisions, deployment strategies, and feature sets. Rather than maintaining separate repositories for each variation, we use a multi-branch approach where each state is represented by a specific commit hash in a dedicated branch.

## Documentation Structure

- **[Strategy Overview](./strategy.md)** - High-level approach and goals
- **[Learning Path Architecture](./learning-path-architecture.md)** - Technical implementation details
- **[Maintenance Strategy](./maintenance-strategy.md)** - How to keep all states current and healthy
- **[Track Definitions](./track-definitions.md)** - The three main learning tracks we'll support
- **[Implementation Roadmap](./implementation-roadmap.md)** - Step-by-step execution plan

## Architecture Decision Records (ADRs)

- **[ADR-001: Multi-Branch State Management](./adr/001-multi-branch-state-management.md)**
- **[ADR-002: Milestone State Selection](./adr/002-milestone-state-selection.md)**
- **[ADR-003: Dependency Management Strategy](./adr/003-dependency-management-strategy.md)**
- **[ADR-004: Testing Strategy Across States](./adr/004-testing-strategy-across-states.md)**
- **[ADR-005: Documentation Generation](./adr/005-documentation-generation.md)**

## Quick Start

For implementers looking to contribute to this strategy, start with:
1. [Strategy Overview](./strategy.md) - Understand the vision
2. [Track Definitions](./track-definitions.md) - See what we're building
3. [Implementation Roadmap](./implementation-roadmap.md) - Know what's next

## Contributing

This documentation is living and should be updated as the strategy evolves. Each major decision should be captured in an ADR, and the implementation roadmap should be kept current with actual progress.
