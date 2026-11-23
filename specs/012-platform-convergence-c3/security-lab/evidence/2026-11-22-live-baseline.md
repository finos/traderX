# Live baseline and initial security checks — 2026-11-22

## Baseline outcome

The inherited State 010, 011 and 012 smoke suites passed against `http://127.0.0.1:18080` in `kind-traderx-security-lab`, namespace `traderx-security-lab`. This covers service behavior, successful trade submission and settled-trade observation, negative input validation, UI contracts, message bus connectivity and observability checks. See [structured baseline result](2026-11-22-c3-baseline-result.json) for command, manifest/log hashes and actual running image IDs.

All 20 workload images are pinned. The reference contains deliberately unhardened demonstration configuration; passing smoke does not make it secure. Published C3 applications run under AMD64 emulation on ARM64, so no native performance or JVM runtime-enforcement conclusions follow.

The source renderer changes only image references, namespace metadata/RBAC/log selector and the CORS origin required by the isolated localhost port. Persistent changes remain in canonical source. The inherited readiness helper incorrectly polled nonexistent `/health` paths on trade-service and trade-processor; their supported `/actuator/health` endpoints now gate readiness. Regression tests retain failure on unhealthy or unreachable applications. Application runtime code was not modified.

## Security fixture outcomes

- [Network/admission result](2026-11-22-platform-result.json): both clients reached the server before policy; after policy, the allowed client succeeded and the unrelated client timed out; a further allowed request succeeded. Restricted Pod Security admission rejected a schema-valid privileged/root workload via server dry-run. This establishes Cilium policy enforcement and admission behavior for the fixtures, not the full C3 flow graph.
- [WAF result](2026-11-22-waf-result.json): Envoy 1.40.2, Coraza proxy-Wasm 0.6.0 (Coraza core 3.3.3, observed embedded CRS 4.14.0). TLS certificate verification was enabled. Query-string and JSON SQL-pattern probes reached a harmless backend in Off and DetectionOnly modes; SQL rules were observed in DetectionOnly. On returned 403 and no corresponding backend receipt. Benign before/after controls returned 200. Only engine mode changed between configuration variants.
- WAF fixture containers were removed after evidence collection. Its artifact checksum matched the publisher's release digest; dependency scanning and hardened image admission have not been performed. Compatibility is not a production-security endorsement. No real SQL exploitation or TraderX RCE was attempted or established.

## Environment and remaining work

Docker's engine-proxy failure was resolved by restart. At the user's direction, state-014's control-plane container was stopped and preserved; Docker RAM remains 6 GB. Its default kubeconfig context is unchanged. Resume it later with `docker start traderx-state-014-control-plane`; stop the lab first if keeping this memory budget.

The isolated lab uses Kubernetes 1.35.0, Cilium chart 1.20.5 and kernel 6.10.14-linuxkit. CALM is deferred independently. Remaining M2 work includes gateway integration choice and runtime observation/enforcement. Tetragon's kind instructions require a suitable host `/proc` mount; current kind configuration does not yet include that mount. Plan the node configuration before claiming runtime-engine compatibility. M3 application identity/authorization, scoped PostgreSQL/NATS credentials, workload/image hardening and complete flow enforcement remain open. No supplier evaluation or CCC compliance is claimed.

All work remains local and uncommitted. No issues, comments, PRs, pushes or remote publication.

## Final validation

The reusable `start-reference.sh` and `test-reference.sh` were executed successfully, confirming a second complete C3 smoke pass from the documented entrypoints. Eighteen focused unit/regression tests and all four repository gates passed. `git diff --check` passed. The WAF preparation script also rebuilt the local image successfully from the checked-in pins and archive hash. Website dependencies are absent, so no website build was run.
