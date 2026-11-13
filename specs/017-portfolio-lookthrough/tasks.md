# Tasks: Portfolio Look-Through

- [x] Define requirements, data model, architecture and API contract.
- [x] Implement deterministic generator and one-time transaction-safe loader.
- [x] Implement SQL traversal and explanation UI.
- [x] Add state generation, lifecycle scripts, Compose routes and metrics.
- [x] Complete integration, browser, regeneration and repository validation; record evidence in PR.

## Experiment redesign (draft PR #499)

- [x] Preserve baseline results, including neutral/negative findings and full screenshots.
- [x] Add a dataset-size control that preserves the exact queried portfolio subgraphs.
- [x] Confirm firm-wide corporate-group impact as the primary task; add an analytical shared-fund fixture.
- [x] Implement equivalent reverse traversals, API/UI and regression coverage beyond 10,000 paths.
- [ ] Validate the synthetic topology with domain reviewers.
- [ ] Compare equivalent queries across overlap/depth, impact fan-out and concurrency.
- [ ] Measure read/update freshness and decide against agreed business requirements.
- [ ] Review the representative example before marking the PR ready.
- [ ] Run the separate full C2 trading end-to-end regression.

## Database-side aggregation follow-up

- [x] Implement database aggregation/ranking and batched selected explanations for both backends.
- [x] Compare analytical totals and exact explanation paths with the retained full-path strategy.
- [x] Record paired database × strategy timings, payload proxies and execution plans.
- [ ] Evaluate concurrency, update freshness and a business latency target separately.

## Counterparty dependency investigation (standalone prototype)

- [x] Define typed-path business question, equivalent semantics and screening criterion before measurement.
- [x] Run PostgreSQL/Falkor comparison against independent path oracle and update/cycle fixtures.
- [x] Publish raw sparse/dense results and decide whether product integration is warranted.
- [ ] Obtain domain review and an agreed business SLA before adoption claims.
