# Implementation Plan: 007 Messaging NATS Replacement

## Scope

- Transition from `003-containerized-compose-runtime` to `007-messaging-nats-replacement`.
- Replace messaging component and protocol while preserving baseline business behavior.
- Keep runtime model on Docker Compose + NGINX ingress (no Kubernetes dependency in this state).

## Technical Approach

1. Define architecture deltas:
   - remove Socket.IO `trade-feed` messaging role,
   - introduce `nats-broker`,
   - define backend and frontend messaging paths.
2. Define event/subject mapping for baseline flows (new trade, account updates, position updates).
3. Define compose and ingress snippets for NATS TCP + WS exposure.
4. Define backend migration rules:
   - publish/subscribe client changes per service.
5. Define frontend migration rules:
   - switch from Socket.IO subscription model to `nats.ws` consumer model (or documented gateway fallback if needed).
6. Define conformance + smoke checks for messaging compatibility and runtime operability.

## Deliverables

1. Requirements and contracts deltas under `requirements/` and `contracts/`.
2. `fidelity-profile.md` for state-level technical profile updates.
3. Updated architecture, topology, and migration guidance documents under `system/`.
4. Component and conformance docs for NATS messaging behavior.
5. Generation hook and smoke-test stubs for follow-on implementation.

## Exit Criteria

- Architecture and migration intent are fully specified and reviewable.
- Runtime wiring examples (compose + ingress) are explicit.
- A clear path exists to implement generation/runtime scripts for state `007`.
- State is ready for implementation phase and subsequent publish to `code/generated-state-007-messaging-nats-replacement`.
