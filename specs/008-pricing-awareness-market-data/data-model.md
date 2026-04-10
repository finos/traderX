# Data Model: Pricing Awareness and Market Data Streaming

## Scope

State `010` extends functional behavior with pricing-aware fields and valuation calculations.

## Entity Impact

- Added:
  - Trade price capture at execution/settlement time.
  - Position valuation fields (market value, cost basis, P&L projections).
- Changed:
  - Position aggregation logic includes price-aware computation outputs.
- Removed: none

## Notes

This state introduces additive functional data for valuation while retaining compatibility with existing account/trade/position workflow boundaries.
