# Tasks: 002 Edge Proxy Uncontainerized

- [x] T201 Define edge routing requirements and update system traceability artifacts.
- [x] T202 Define edge runtime topology and startup ordering.
- [x] T203 Implement generation templates/manifests for edge routing behavior.
- [x] T204 Regenerate impacted components/runtime scripts.
- [ ] T205 Execute conformance and smoke checks for impacted baseline flows.
- [x] T205a Add state-002 smoke test script (`scripts/test-state-002-edge-proxy.sh`).
- [ ] T206 Publish generated snapshot tag with evidence links.
- [ ] T207 Add/verify edge-routed GUI state-awareness requirements inherited from state `001` (header + About metadata + API explorer link).
- [ ] T208 Add state `Status` page requirements and edge-health data contract in system artifacts.
- [ ] T209 Extend smoke coverage to assert About metadata rendering and Status-page uptime/health visibility through edge endpoint.
- [ ] T210 Add startup/runtime state-mismatch detection checks for state `002` scripts (match, mismatch, opt-in regeneration path).
