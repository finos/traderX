# Evidence contract v1

Each result is a JSON object. `scenario_id` references `scenarios.json`; `profile` is `reference`, `hardened-observation`, `hardened-enforcement`, `candidate` or `combined`. Include `run_id`, a full `generated_commit`, a 64-character `configuration_sha256` and `collector_ref` to independently held records. The complete run bundle must additionally retain baseline/profile/image pins, active controls and their verification, workload definition, timestamps and performance samples.

Boolean fields: `positive_control_passed`, `attempt_executed`, `asynchronous_settled`, `normal_workflow_passed`, `effect_observed`, `alert_observed`, `containment_observed`. Unknown observations require `outcome: inconclusive`; boolean fields may record only what was actually observed. Record explanatory limitations alongside results.

Conclusive results require nonempty `before_ref`, `after_ref`, and `application_receipt_ref` (including evidence that an application did not receive a gateway-rejected request). References identify independent collector artifacts; they are not raw credentials or payload dumps.

`outcome` is one of:

- `prevented`: no observed effect after settlement, healthy positive/normal controls and an attributed `decision_ref` from an allowed `intervening_layer` for this scenario.
- `detected`: an alert and decision reference exist; effect may already have occurred.
- `contained`: independently observed containment and decision reference exist; this does not imply absence of earlier impact.
- `allowed`: effect was independently observed, regardless of whether it was intended.
- `inconclusive`: missing/failed controls, unavailable evidence, timeout or unsettled downstream processing.

Validator success checks field consistency only. It cannot authenticate a reference, prove that a request reached its intended target or establish that telemetry is truthful. A future collector must verify artifact hashes, timestamp/run correlation, isolation and signatures before accepting measured results. No synthetic test result is runtime evidence.

For WAF comparisons record mode and keep all other controls/configuration identical. For canaries record original and final synthetic row state, committed transaction outcome and a bounded settlement observation. Recovery evidence records reset plus another normal trade. Performance evidence includes workload/sample counts and duration, p95/p99, throughput, CPU/memory, alert delay and recovery time.
