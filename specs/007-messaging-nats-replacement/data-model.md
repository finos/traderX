# Data Model: Messaging Layer Replacement with NATS

## Scope

State `007` primarily changes messaging transport and topic strategy.

## Entity Impact

- Added: none (business entities remain baseline-compatible)
- Changed: event routing semantics (`TradeOrder`, trade updates, position updates via NATS subjects)
- Removed: direct dependency on Socket.IO feed protocol for service-to-service messaging

## Notes

Persistence schema and REST contract payloads remain compatible; messaging contract changes are captured in this state's system/requirements artifacts.
