# Trade-Service Verification Checklist

## Startup Verification

- [ ] Generated component exists in `generated/code/components/trade-service-specfirst`.
- [ ] `./gradlew build` completes.
- [ ] Service starts and listens on port `18092`.

## Functional Verification

- [ ] `POST /trade/` with valid account/ticker returns `200`.
- [ ] Unknown ticker returns `404`.
- [ ] Unknown account returns `404`.
- [ ] Accepted trade order is published to `/trades` and processed by trade-processor.

## Compatibility Verification

- [ ] Angular UI trade submission remains functional in mixed mode.
- [ ] position-service reflects resulting trade/position updates for submitted orders.
- [ ] No regressions in end-to-end trade flow caused by trade-service replacement.

## Suggested Commands

```bash
./scripts/test-trade-service-overlay.sh
./scripts/test-position-service-overlay.sh
```
