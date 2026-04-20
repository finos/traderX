# Non-Functional Delta: 014-fdc3-intent-interoperability

Parent state: `012-platform-convergence-c3`

This state introduces desktop interoperability concerns while preserving C3 runtime foundations.

## Runtime / Operations

- Base runtime topology from state `012` remains intact.
- FDC3 integration is frontend-scoped and depends on a compatible DesktopAgent at runtime.
- TraderX must operate in two modes:
  - interop-enabled (agent available)
  - degraded/local-only (agent unavailable)
- Generated runtime artifacts should include explicit notes for optional demo-agent (Sail/profile) validation.
- Local Sail sidecar should run as an independent service (for example local Docker container or equivalent), outside TraderX ingress path.
- Sail sidecar default endpoint should remain `http://localhost:8090` unless explicitly overridden.

## Security / Compliance

- App integration targets FDC3 2.2 API semantics for application interoperability.
- This state does not implement a desktop agent; it implements app-side FDC3 behavior plus local demo-agent packaging.
- Outbound context payloads should include symbol identifiers only (ticker plus optional public identifiers such as ISIN/FIGI/RIC), excluding account/user-sensitive fields.
- Intent handlers must validate context shape before applying UI actions.
- TraderX should publish canonical bare ticker payloads and must not embed Sail-widget-specific exchange remapping logic.
- Any tactical compatibility logic required for specific Sail demo widgets (for example exchange qualification for TradingView symbol strings) must be isolated to Sail-side pre-build/startup patch assets and marked as temporary technical debt until CDM-native identifier normalization lands.
- Workaround-driven interoperability behavior must be explicitly tracked as technical debt and reviewed for removal once Sail event delivery and normalized symbology are production-ready.

## Performance / Scalability

- Context broadcasts should be deduplicated for unchanged ticker selection to avoid excessive event traffic.
- Listener callbacks should avoid blocking UI rendering and should not regress existing blotter responsiveness.
- Current Sail demo behavior may require an app-side context-sync fallback path (active-channel context polling with dedupe) to compensate for inconsistent context callback delivery; this remains a temporary workaround.
- Sidecar startup should not materially increase TraderX startup critical path unless explicitly requested by runtime flags.
- No additional backend scaling requirements are introduced in this state.

## Reliability / Observability

- Interop failures (missing agent, unsupported intent, malformed context) must degrade safely and keep core TraderX workflows functional.
- Sidecar failures (Sail unavailable) must not break TraderX baseline runtime health checks.
- Frontend logs should include structured interoperability events for diagnostics:
  - outbound context publish attempts
  - inbound context/intent handling outcomes
  - degraded-mode fallbacks
- Existing C3 observability endpoints remain required and unchanged.
