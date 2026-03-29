# Data Model: Simple App - Base Uncontainerized App

## Domain Entities

### Account
- **Attributes**: `id`, `displayName`
- **Notes**: Core aggregate for blotter scope and trade ownership.

### AccountUser
- **Attributes**: `accountId`, `username`
- **Notes**: Many-to-many mapping for account entitlements seed behavior.

### Person
- **Attributes**: `logonId`, `fullName`, `email`, `employeeId`, `department`, `photoUrl`
- **Notes**: Returned by people-service for validation and lookup.

### SecurityReference
- **Attributes**: `ticker`, `companyName`
- **Notes**: Reference-data ticker universe.

### TradeOrder
- **Attributes**: `accountId`, `security`, `side`, `quantity`
- **Notes**: Input command accepted by trade-service.

### Trade
- **Attributes**: `id`, `accountId`, `security`, `side`, `quantity`, `state`, timestamps
- **Notes**: Trade lifecycle record persisted by trade-processor.

### Position
- **Attributes**: `accountId`, `ticker`, `quantity`
- **Notes**: Aggregated position updated from processed trades.

## Relationships

- Account 1..* Trade
- Account 1..* Position
- Account *..* Person (via AccountUser)
- TradeOrder -> Trade (processing projection)
- Trade events -> Position updates (via trade-processor pipeline)

## Contract Surfaces

- REST APIs: account-service, position-service, trade-service, people-service, reference-data
- Event APIs: trade-feed topics for new trades and account-scoped updates
