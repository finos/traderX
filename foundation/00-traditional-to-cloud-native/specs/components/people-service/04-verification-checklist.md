# People-Service Verification Checklist

## Startup Verification

- [ ] Generated component exists in `generated/code/components/people-service-specfirst`.
- [ ] `dotnet build` completes for `PeopleService.WebApi`.
- [ ] Service starts and listens on port `18089`.

## API Verification

- [ ] `GET /People/GetPerson?LogonId=user01` returns `200`.
- [ ] `GET /People/GetPerson?LogonId=DOES_NOT_EXIST` returns `404`.
- [ ] `GET /People/GetMatchingPeople?SearchText=user&Take=5` returns `200` with `people` array.
- [ ] `GET /People/ValidatePerson?LogonId=user01` returns `200`.
- [ ] `GET /People/ValidatePerson?LogonId=DOES_NOT_EXIST` returns `404`.

## Compatibility Verification

- [ ] Angular user search can retrieve matching people without CORS errors.
- [ ] account-service user validation flow can resolve known users through generated people-service.

## Suggested Commands

```bash
curl -i "http://localhost:18089/People/GetPerson?LogonId=user01"
curl -i "http://localhost:18089/People/GetMatchingPeople?SearchText=user&Take=5"
curl -i "http://localhost:18089/People/ValidatePerson?LogonId=DOES_NOT_EXIST"
```
