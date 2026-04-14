# Smoke Coverage: 001 Baseline Uncontainerized Parity

- Primary runtime smoke scripts:
  - `scripts/test-reference-data-overlay.sh`
  - `scripts/test-database-overlay.sh`
  - `scripts/test-people-service-overlay.sh`
  - `scripts/test-account-service-overlay.sh`
  - `scripts/test-position-service-overlay.sh`
  - `scripts/test-trade-feed-overlay.sh`
  - `scripts/test-trade-processor-overlay.sh`
  - `scripts/test-trade-service-overlay.sh`
  - `scripts/test-web-angular-overlay.sh`
  - `scripts/test-web-angular-baseline-ux-contract.sh`

- Required GUI smoke assertions for this state:
  - Header title renders `TraderX Sample Trading App (001-baseline-uncontainerized-parity)`.
  - Top navigation includes an `About` entry.
  - About page renders state id, generation timestamp, source branch, prior-state lineage branch list, and short feature-summary sentence per prior state.
  - About page includes a link to API explorer.

- Required runtime smoke assertions for this state:
  - Runtime start script reports currently generated state id before startup.
  - Runtime start script reports guidance for mismatch handling (forward-regenerate vs backward clean rebuild).
  - Optional auto-regenerate mode can be enabled explicitly to regenerate expected state before startup.
