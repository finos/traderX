# Tasks: Portfolio Look-Through

- [x] Define requirements, data model, architecture and API contract.
- [x] Implement deterministic generator and one-time transaction-safe loader.
- [x] Implement SQL traversal and explanation UI.
- [x] Add state generation, lifecycle scripts, Compose routes and metrics.
- [x] Complete integration, browser, regeneration and repository validation; record evidence in PR.

## Experiment redesign (draft PR #499)

- [x] Preserve baseline results, including neutral/negative findings and full screenshots.
- [x] Add a dataset-size control that preserves the exact queried portfolio subgraphs.
- [ ] Confirm the primary business task and representative portfolio topology.
- [ ] Compare equivalent queries across overlap/depth, impact fan-out and concurrency.
- [ ] Measure read/update freshness and decide against agreed business requirements.
- [ ] Review the representative example before marking the PR ready.
- [ ] Run the separate full C2 trading end-to-end regression.
