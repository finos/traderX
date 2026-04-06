# Data Model: PostgreSQL Database Replacement

## Scope

State `009` keeps the same business entities as prior states and changes database engine/runtime from H2 to PostgreSQL.

## Entity Impact

- Added: none
- Changed: physical schema implementation details to PostgreSQL-compatible DDL/types
- Removed: dependency on H2-specific runtime assumptions

## Notes

Data model semantics are intentionally preserved. This is a persistence-engine substitution state, not a functional domain redesign.
