# Trade-Feed Verification Checklist

## Startup Verification

- [ ] Generated component exists in `codebase/generated-components/trade-feed-specfirst`.
- [ ] `npm install` completes.
- [ ] Service starts and listens on port `18086`.

## Functional Verification

- [ ] Socket client can `subscribe` to a topic.
- [ ] Socket client can `publish` to a topic and receive wrapped publish events.
- [ ] Messages are also visible on wildcard `/*` topic.
- [ ] `unsubscribe` works for active subscribers.
- [ ] Legacy `unusbscribe` command remains accepted for compatibility.

## Compatibility Verification

- [ ] Angular UI websocket subscriptions receive expected account topic updates.
- [ ] trade-service and trade-processor publish events are visible in subscribers.
- [ ] No regressions in trade/order flow caused by broker change.

## Suggested Commands

```bash
curl -i "http://localhost:18086/"
# plus socket client checks via UI or script harness
```
