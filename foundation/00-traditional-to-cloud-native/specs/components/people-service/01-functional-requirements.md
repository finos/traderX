# People-Service Functional Requirements

## Scope

Define baseline functional behavior for the next pure-generated cutover target: `people-service`.

## Functional Requirements

- FR-PS-001: The service shall expose `GET /People/GetPerson` and accept `LogonId` or `EmployeeId` query input.
- FR-PS-002: `GET /People/GetPerson` shall return HTTP `200` and person JSON when a matching identity exists.
- FR-PS-003: `GET /People/GetPerson` shall return HTTP `404` when no person matches the provided identity.
- FR-PS-004: `GET /People/GetMatchingPeople` shall accept `SearchText` and optional `Take` query inputs.
- FR-PS-005: `GET /People/GetMatchingPeople` shall return HTTP `200` with payload `{ "people": [...] }` when one or more matches exist.
- FR-PS-006: `GET /People/GetMatchingPeople` shall return HTTP `404` when no matches exist.
- FR-PS-007: `GET /People/ValidatePerson` shall return HTTP `200` when person identity is valid and HTTP `404` when invalid.
- FR-PS-008: Person payload shape shall remain compatible with existing consumers (`logonId`, `fullName`, `email`, `employeeId`, `department`, `photoUrl`).
- FR-PS-009: Service directory data shall load from baseline JSON file (`MockDirectory/people.json`).
- FR-PS-010: Requests missing required query inputs shall return HTTP `400`.

## Out Of Scope

- No directory backend integration (e.g., LDAP/AD) in this phase.
- No auth/authz redesign in this phase.
- No endpoint path redesign in this phase.
