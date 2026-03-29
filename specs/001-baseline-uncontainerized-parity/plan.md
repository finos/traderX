# Implementation Plan: Simple App - Base Uncontainerized App

**Branch**: `001-baseline-uncontainerized-parity` | **Date**: 2026-03-28 | **Spec**: `/specs/001-baseline-uncontainerized-parity/spec.md`  
**Input**: Feature specification from `/specs/001-baseline-uncontainerized-parity/spec.md`

## Summary

Capture and enforce TraderX baseline runtime behavior in canonical Spec Kit feature artifacts at repo root, while preserving current generated runtime behavior and compatibility contracts.

## Generation Approach

Spec Kit is the requirements/planning workflow and does not impose a single code-emission engine.  
For TraderX baseline parity, generation uses this chain:

1. Plain-English FR/user-story requirements define behavior.
2. Technical NFRs define implementation shape (language/framework/ports/env/contracts/dependencies).
3. Component manifests compile deterministic generation inputs.
4. Synthesis generators emit code from manifests and templates.
5. Conformance + semantic compare gates verify closeness to approved baseline.

## Technical Context

**Language/Version**: Java 21 (Spring Boot services), TypeScript/Node.js (Nest + Socket.IO + Angular), C# (.NET 9), SQL (H2)  
**Primary Dependencies**: Spring Boot, Gradle, NestJS, Socket.IO, ASP.NET Core, Angular, H2  
**Storage**: H2 over TCP/PG/Web ports  
**Testing**: Existing overlay smoke scripts in `scripts/*.sh`  
**Target Platform**: Local developer workstation (macOS/Linux), pre-containerized process runtime  
**Project Type**: Distributed multi-service web application  
**Performance Goals**: Functional parity and deterministic startup/health behavior over raw throughput  
**Constraints**: Contract compatibility, CORS in pre-ingress mode, stable port mapping, no hidden hydration dependency  
**Scale/Scope**: 9 baseline processes/services + Angular UI

## Constitution Check

- Pass: Root-level feature-scoped spec pack created.
- Pass: Contract compatibility explicitly gated.
- Pass: Deterministic startup and evidence-gated verification included.
- Pass: Hydration treated as transitional, not end-state.

## Project Structure

### Documentation (this feature)

```text
specs/001-baseline-uncontainerized-parity/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── fidelity-profile.md
├── quickstart.md
├── contracts/
│   ├── account-service/openapi.yaml
│   ├── people-service/openapi.yaml
│   ├── position-service/openapi.yaml
│   ├── reference-data/openapi.yaml
│   ├── trade-processor/openapi.yaml
│   └── trade-service/openapi.yaml
└── tasks.md
```

### Source Code (repository root)

```text
TraderSpec/
├── codebase/
│   ├── generated-components/
│   └── scripts/
├── pipeline/
│   └── speckit/
└── migration-*.md

.specify/
.agents/skills/
specs/
```

**Structure Decision**: Keep current generated runtime under `TraderSpec/` during transition, but make root `.specify` and root `specs/NNN-*` the canonical requirements workflow.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| Temporary dual structure (`specs/` + `TraderSpec/speckit/`) | Avoid runtime disruption during migration | Big-bang move risks losing working generation/test pipeline continuity |
