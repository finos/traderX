# 02 Non-Functional Requirements Baseline

These baseline NFRs apply to all tracks unless explicitly superseded.

## NFR-001 Build Reproducibility

Each service must have deterministic local build commands.

## NFR-002 Local Operability

The platform must run locally with documented startup order.

## NFR-003 API Compatibility Discipline

Service API changes require explicit contract updates and migration notes.

## NFR-004 Testability

Core workflows require automated smoke tests.

## NFR-005 Traceable Change

Each step must map requirements to implementation and validation evidence.

## NFR-006 Local Cross-Origin Operability

In the pre-container, pre-ingress base state, HTTP services must allow cross-origin requests between local service/UI ports so workflows function without a unified proxy.
