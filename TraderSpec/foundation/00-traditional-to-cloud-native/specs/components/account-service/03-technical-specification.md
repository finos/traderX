# Account-Service Technical Specification

## Component Identity

- Component ID: `account-service`
- Type: service
- Baseline language/runtime: Java + Spring Boot
- Build/run tool: Gradle (`./gradlew bootRun`)
- Default port: `18088`

## Runtime Configuration

- `ACCOUNT_SERVICE_PORT` (default `18088`)
- `DATABASE_TCP_HOST` (default `localhost`)
- `DATABASE_TCP_PORT` (default `18082`)
- `DATABASE_NAME` (default `traderx`)
- `DATABASE_DBUSER` (default `sa`)
- `DATABASE_DBPASS` (default `sa`)
- `PEOPLE_SERVICE_URL` or `PEOPLE_SERVICE_HOST` (default `http://localhost:18089`)

## API Contract

- `GET /account/{id}`
- `GET /account/`
- `POST /account/`
- `PUT /account/`
- `GET /accountuser/{id}`
- `GET /accountuser/`
- `POST /accountuser/`
- `PUT /accountuser/`

## Integration Contract

- Database: reads/writes `Accounts` and `AccountUsers` tables via Spring Data/JPA.
- People service: validates account-user creation with `GET /People/GetPerson?LogonId=<username>`.
- Error behavior: return `404` for people-service validation failure on account-user create.

## Build And Run Behavior

- Build: `./gradlew build`
- Run: `./gradlew bootRun`
- Readiness: TCP probe on `localhost:18088`

## Source Layout Target (Generated)

- Target path: `TraderSpec/codebase/generated-components/account-service-specfirst`
- Required generated artifacts:
  - Spring Boot service with account and account-user controllers
  - data-access layer compatible with baseline H2 schema
  - people-service validation adapter for account-user create flow
