# People-Service Technical Specification

## Component Identity

- Component ID: `people-service`
- Type: service
- Baseline language/runtime: C# + ASP.NET Core
- Build/run tool: `dotnet`
- Default port: `18089`

## Runtime Configuration

- `PEOPLE_SERVICE_PORT` (default `18089`)
- `CORS_ALLOWED_ORIGINS` (default `*`)
- `PeopleJsonFilePath` from `appsettings.json` (default `MockDirectory/people.json`)

## API Contract

- `GET /People/GetPerson?LogonId=<id>&EmployeeId=<id>`
- `GET /People/GetMatchingPeople?SearchText=<text>&Take=<n>`
- `GET /People/ValidatePerson?LogonId=<id>&EmployeeId=<id>`

## Data Contract

- Person JSON fields:
  - `logonId`
  - `fullName`
  - `email`
  - `employeeId`
  - `department`
  - `photoUrl`
- Baseline data source: JSON file in component path (`PeopleService.WebApi/MockDirectory/people.json`).

## Build And Run Behavior

- Build: `dotnet restore` and `dotnet build` in `PeopleService.WebApi`
- Run: `dotnet run` in `PeopleService.WebApi`
- Readiness: TCP probe on `localhost:18089`

## Source Layout Target (Generated)

- Target path: `TraderSpec/codebase/generated-components/people-service-specfirst`
- Required generated artifacts:
  - runnable ASP.NET Core Web API project
  - baseline endpoint contract compatibility for `GetPerson`, `GetMatchingPeople`, `ValidatePerson`
  - JSON-backed directory data source
  - CORS configuration for pre-ingress local cross-origin access
