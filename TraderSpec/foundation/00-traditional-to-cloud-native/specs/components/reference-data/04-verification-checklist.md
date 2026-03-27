# Reference-Data Verification Checklist

## Contract Verification

- [ ] `/stocks` returns HTTP `200` with JSON array.
- [ ] `/stocks/{ticker}` returns HTTP `200` for known ticker.
- [ ] `/stocks/{ticker}` returns HTTP `404` for unknown ticker.
- [ ] `/health` returns HTTP `200`.

## Compatibility Verification

- [ ] `trade-service` successfully resolves ticker via reference-data endpoint.
- [ ] Angular UI symbol search renders valid results from reference-data.

## Operational Verification

- [ ] Service starts on port `18085`.
- [ ] Startup logs include service ready signal.
- [ ] No unhandled exceptions on baseline request set.

## Suggested Commands

```bash
curl -i http://localhost:18085/health
curl -i http://localhost:18085/stocks
curl -i http://localhost:18085/stocks/AAPL
curl -i http://localhost:18085/stocks/DOES_NOT_EXIST
```
