# Quickstart

Prerequisites: Docker Compose, Python 3.12+, Node/npm, jq, rsync and the inherited generator prerequisites. Windows: use WSL2, or invoke the `.ps1` lifecycle wrapper from PowerShell.

```bash
bash pipeline/generate-state.sh 018-falkordb-lookthrough
scripts/start-state-018-falkordb-lookthrough-generated.sh --dry-run
scripts/start-state-018-falkordb-lookthrough-generated.sh
scripts/test-state-018-falkordb-lookthrough.sh
scripts/status-state-018-falkordb-lookthrough-generated.sh
scripts/stop-state-018-falkordb-lookthrough-generated.sh
```

Open http://localhost:8080/exposure/ (also http://localhost:18120 directly). Select portfolio 70000 and corporate entity Z0G for the 14% scenario. A link in the TraderX header opens the exposure view.

Set EXPOSURE_PROFILE=small for quick startup; demo is default; benchmark is opt-in. Use a fresh isolated database when changing profile. Restarting with the same profile preserves source changes. Stop does not delete volumes.

To demonstrate an update, use the local database operator interface to change `Positions.quantity` for account 70000/security Z0S from 20 to 40. Wait for /health to show a new revision, then Calculate exposure. The new result is 16000 / 102000, approximately 15.6863%. Restore quantity 20 after the demo.

Integration tests: create a virtual environment, install `specs/017-portfolio-lookthrough/generation/exposure-service/requirements.txt`, then run `python scripts/test-exposure-integration.py` with EXPOSURE_TEST_DSN and EXPOSURE_TEST_REDIS_URL pointing at isolated disposable PostgreSQL and FalkorDB. Tests reset only the isolated test database; do not point them at a demo or production database. Browser test: `python scripts/test-exposure-browser.py` with Playwright installed and the exposure service running.
