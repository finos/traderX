# Database Verification Checklist

## Startup Verification

- [ ] Build completes (`./gradlew build`).
- [ ] DB startup script launches successfully.
- [ ] Port `18082` accepts TCP connections.
- [ ] Port `18083` accepts PG-protocol connections.
- [ ] Port `18084` web console is reachable.

## Schema/Data Verification

- [ ] `Accounts`, `AccountUsers`, `Positions`, `Trades` tables exist.
- [ ] `ACCOUNTS_SEQ` exists.
- [ ] Baseline seed rows exist for known accounts (`22214`, `52355`, etc.).

## Compatibility Verification

- [ ] account-service can query account data.
- [ ] position-service can query positions.
- [ ] trade-processor can persist updates.

## Suggested Commands

```bash
nc -z localhost 18082
nc -z localhost 18083
curl -i http://localhost:18084/
```
