# Account-Service Verification Checklist

## Startup Verification

- [ ] Generated component exists in `generated/code/components/account-service-specfirst`.
- [ ] `./gradlew build` completes.
- [ ] Service starts and listens on port `18088`.

## API Verification

- [ ] `GET /account/22214` returns `200` and baseline account payload.
- [ ] `GET /account/` returns non-empty account list.
- [ ] `GET /accountuser/` returns non-empty mapping list.
- [ ] `POST /accountuser/` with valid user returns `200`.
- [ ] `POST /accountuser/` with unknown user returns `404`.

## Compatibility Verification

- [ ] Angular UI account screens load data successfully.
- [ ] Trade flow dependencies are unaffected by generated account-service.
- [ ] Generated account-service interoperates with generated database and generated people-service.

## Suggested Commands

```bash
curl -i "http://localhost:18088/account/22214"
curl -i "http://localhost:18088/accountuser/"
curl -i -X POST "http://localhost:18088/accountuser/" -H "Content-Type: application/json" -d '{"accountId":22214,"username":"user01"}'
curl -i -X POST "http://localhost:18088/accountuser/" -H "Content-Type: application/json" -d '{"accountId":22214,"username":"does_not_exist"}'
```
