# Functional Delta: 009-order-management-matcher

Parent state: `008-pricing-awareness-market-data`

Document only functional behavior changes introduced by this state.

## Added

- Order domain with lifecycle states (`NEW`, `PARTIALLY_FILLED`, `FILLED`, `CANCELED`, `REJECTED`).
- Order matcher component (Java Spring Boot) for evaluating executable orders and publishing fill events.
- Order management API surface for create/list/cancel/force-fill workflows.
- Database-backed order persistence so active orders survive order-matcher restarts.
- Tick-driven auto-fill policy for in-the-money orders:
  - remaining quantity `< 1000`: fill full remaining quantity
  - remaining quantity `>= 1000`: fill half (rounded up)
- Trader UI order ticket for limit-order creation, separated from market-trade ticket workflow.
- Trader UI account-level open-order blotter (tabbed alongside trade/position context) with user cancel action.
- Admin screen (`Admin` tab) with a filterable order blotter for all accounts and operational force-fill/cancel actions.
- Realtime order stream updates for pending/fill/cancel transitions.
- Explicit realtime-subscription contract for all live TraderX blotters (trade, position, account orders, admin orders), with REST bootstrap + stream continuation.

## Changed

- Trade submission flow can now originate from direct market trade path or from matched order flow.
- Position/trade updates can be sourced from matcher-generated fills in addition to ticket-driven trades.
- Order fill path is now explicit: matched order -> trade-service submit -> trade-processor persistence -> position-service update.
- UI navigation includes an admin entrypoint for order operations and status visibility.
- Trade area adds an order-first interaction path: create limit order, monitor outstanding orders, and cancel from account context.
- Realtime UI path is now standardized across live views: initial REST hydration followed by push-driven incremental updates.

## Removed

- No removals in this state.

## Flow Impact

- `F2` (submit and process trade): extended to include fill generation from order matching.
- `F4` (realtime updates): extended with order lifecycle stream topics and admin updates.
- `F4` now explicitly covers all live blotters (trade, position, account orders, admin orders) using pub/sub after bootstrap.
- New functional flow: `F5` (order management and matching lifecycle end-to-end).
- New functional flow: `F6` (trader order ticket + account orders blotter cancel workflow).
