# Architecture Path Spec

## Track Objective

Evolve core architecture patterns (messaging, topology, modeling) independently from DevEx and feature-only tracks.

## Requirement Layering

- Baseline FR: inherited unless explicitly changed.
- Architecture deltas: transport, protocol, and component-boundary changes.
- NFR: additive around operability, reliability, and interoperability for architecture choices.

## Canonical Progression

`003-containerized-compose-runtime -> 007-messaging-nats-replacement -> 008-kubernetes-runtime-with-nats (planned)`

## Execution Entry

- `docs/spec-kit/spec-kit-learning-path-strategy.md`
- `docs/spec-kit/state-transition-generation-plan.md`
