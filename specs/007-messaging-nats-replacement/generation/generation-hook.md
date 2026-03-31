# Generation Hook: 007 Messaging NATS Replacement

- Hook script: `pipeline/generate-state-007-messaging-nats-replacement.sh`
- Feature pack: `specs/007-messaging-nats-replacement`

## Intended Hook Flow

1. Generate state `003` as base output.
2. Replace messaging layer artifacts:
   - remove Socket.IO `trade-feed` runtime component,
   - add NATS broker runtime artifacts.
3. Apply service and frontend migration deltas:
   - backend NATS publish/subscribe wiring,
   - frontend `nats.ws` stream wiring.
4. Apply ingress and compose deltas from `system/` snippets.
5. Emit deterministic target output for state `007`.

## Implementation Notes

- Keep business behavior aligned with prior state.
- Limit this state to messaging transport/topology change.
- Preserve readiness for a future Kubernetes-on-007 follow-up state.
