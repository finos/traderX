# Upstream Follow-Ups: FDC3 v3 / Sail v3 Beta

This file tracks potential upstream contributions discovered while building the state 014 FDC3 v3 alpha and Sail v3 beta demo. These are not submitted upstream yet.

## Sail Candidates

- Stable workspace bootstrap hook: TraderX currently patches Sail `workspace-store.ts` to seed and activate a demo workspace. Upstream Sail may benefit from a supported startup/configuration mechanism for default workspaces, active workspace selection, and seeded panel layout.
- Import/export workspace profile: Demo operators need a way to capture a configured Sail workspace from browser storage and replay it in another environment without editing Sail source.
- Open issue: [FINOS/FDC3-Sail#313](https://github.com/finos/FDC3-Sail/issues/313) tracks workspace persistence, `Map` serialization, and supported default workspace/profile hooks.
- FDC3 toolbox example consumption: TraderX now consumes TradingView/Pricer examples from `@finos/fdc3-example-apps@3.0.0-alpha.2` instead of carrying Sail-local widget ports. If the examples need additional current-context or frameability hardening, that belongs in the FDC3 toolbox package rather than in Sail.
- Multi-App Directory sources: Sail web should expose supported configuration for multiple FDC3 App Directory sources instead of requiring apps to be passed as a single pre-merged fixture array. The useful shape for state 014 is both startup configuration (for example `SAIL_APP_DIRECTORY_URLS=http://localhost:8080/fdc3/appd,http://localhost:4023/fdc3/appd`) and a runtime GUI for adding/removing sources during a demo.
- App Directory source status UI: Sail should show loaded directory sources, app counts, duplicate/skipped app ids, and source load failures so demo operators can distinguish unavailable app providers from resolver bugs.
- User-channel callback reliability: TraderX currently keeps a bounded active-channel context-sync fallback because callback delivery can be inconsistent in demo runs. Upstream Sail should be checked for reproducible callback gaps before this becomes a TraderX workaround permanently.
- AppD/local port ergonomics: Sail demo directories should avoid advertising local app entries when their backing services are not running. TraderX currently filters/seeds only reachable demo apps.
- Zustand store API compatibility: TraderX patches Sail UI hook usage around the connection store to avoid `api.getState is not a function` failures. If still present upstream, this should be fixed in Sail rather than patched at startup.

## FDC3 Candidates / Watch Items

- Open issue: [FINOS/FDC3#1943](https://github.com/finos/FDC3/issues/1943) tracks FDC3 v3 alpha implementer feedback around route-scoped web identity, context-only apps, and custom context guidance.
- Confirm final FDC3 v3 `getAgent()` API shape before replacing the `3.0.0-alpha.2` pin with a stable package.
- Confirm whether route-specific web identities such as `/trade` and `/mini-traderx` are the intended pattern for multiple FDC3 apps hosted by one origin.
- Confirm best practice for custom domain context types such as `traderx.account`, especially around identity-only payloads and privacy boundaries.
- Revisit intent registration once v3 GA behavior is stable; Mini TraderX should remain context-only and must not be selected for TraderX ticket intents.

## Workspace Capture Notes

- Sail workspace persistence currently uses browser `localStorage` key `workspace-store`.
- The persisted state includes workspace records, active workspace id, tabs, panels, and Dockview layout state.
- TraderX state 014 currently patches Sail startup to ensure `traderx-fdc3-demo-workspace` exists and is active on load.
- A future capture flow can read `localStorage.getItem("workspace-store")` from an already-configured Sail tab, normalize volatile timestamps/ids as needed, and convert that snapshot into the state 014 seeded workspace block.
