# State 016 acceptance harness

Estate-owned headless E2E coverage for the offline acceptance flow (10 gates,
see `../README.md`). Not FINOS-upstream: it assumes headless Chrome and local
tooling. The manual acceptance script a maintainer needs is
`../../acceptance-demo.md` — this harness only automates proving it.

```bash
# 1. Serve the spec pack (repo root):
python3 -m http.server 8090 --directory specs/016-post-trade-settlement-bankerx

# 2. Install + run the harness (Chrome executable overridable via CHROME_EXE):
cd specs/016-post-trade-settlement-bankerx/acceptance/harness
npm install
node acceptance-016.cjs http://localhost:8090 clean-run
```

Gates: `realFdc3`, `deskOpen`, `wcpConnected`, `tradeBooked`, `intentReceived`,
`acsc`, `receiptModal`, `dupSuppressed`, `receiverDupReplay`, `rejectHonest`.
Exit code 0 iff all 10 pass. On failure it dumps filtered console evidence.