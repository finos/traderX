# Position-Service Verification Checklist

## Startup Verification

- [ ] Generated component exists in `codebase/generated-components/position-service-specfirst`.
- [ ] `./gradlew build` completes.
- [ ] Service starts and listens on port `18090`.

## API Verification

- [ ] `GET /trades/22214` returns `200` and non-empty trade list.
- [ ] `GET /positions/22214` returns `200` and non-empty position list.
- [ ] `GET /trades/` returns non-empty list.
- [ ] `GET /positions/` returns non-empty list.
- [ ] `GET /health/ready` returns healthy response.
- [ ] `GET /health/alive` returns healthy response.

## Compatibility Verification

- [ ] Angular blotter bootstrap loads positions/trades successfully.
- [ ] Generated position-service interoperates with generated database.
- [ ] Trade submission flow remains compatible with downstream views.

## Suggested Commands

```bash
curl -i "http://localhost:18090/trades/22214"
curl -i "http://localhost:18090/positions/22214"
curl -i "http://localhost:18090/health/ready"
curl -i "http://localhost:18090/health/alive"
```
