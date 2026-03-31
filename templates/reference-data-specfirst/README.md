# Reference-Data (Spec-First Generated)

This component is generated from TraderSpec component requirements, without hydrating source files from the root implementation.

## Run

```bash
npm install
npm run start
```

Default port: `18085` (override with `REFERENCE_DATA_SERVICE_PORT`).

## CORS (Baseline State Requirement)

- Default: allow all origins (`CORS_ALLOWED_ORIGINS=*`).
- Optional: comma-separated allowlist via `CORS_ALLOWED_ORIGINS`.

## Dataset

- Loads stock symbols from `data/s-and-p-500-companies.csv` (baseline parity dataset).
- Optional universe filter: `REFERENCE_DATA_SUPPORTED_TICKERS` (comma-separated tickers).
- Optional cap after filtering: `REFERENCE_DATA_MAX_TICKERS` (positive integer).
- Includes supplemental sample symbols when needed for learning scenarios:
  - `MS`, `UBS`, `C`, `GS`, `DB`, `JPM`, `COF`, `DFS`, `FNMA`, `FIS`, `FNF`.
