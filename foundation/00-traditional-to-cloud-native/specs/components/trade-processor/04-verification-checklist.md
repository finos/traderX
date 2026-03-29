# Trade-Processor Verification Checklist

## Startup Verification

- [ ] Generated component exists in `codebase/generated-components/trade-processor-specfirst`.
- [ ] `./gradlew build` completes.
- [ ] Service starts and listens on port `18091`.

## Functional Verification

- [ ] Publishing a `TradeOrder` to `/trades` results in persisted trade and position updates.
- [ ] `POST /tradeservice/order` returns `trade` + `position` payload.
- [ ] Buy and sell quantity math updates positions correctly.
- [ ] Generated trade state reaches `Settled`.
- [ ] Outbound publish notifications are emitted on account-scoped trade/position topics.

## Compatibility Verification

- [ ] Trade-service submitted orders are consumed and processed without payload mismatch.
- [ ] Position-service still reads updated trade/position tables without schema regression.
- [ ] Angular UI trade flow remains functional in mixed mode.

## Suggested Commands

```bash
./scripts/test-trade-processor-overlay.sh
./scripts/test-position-service-overlay.sh
```
