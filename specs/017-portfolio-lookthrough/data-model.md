# Data model

## Demo universe
| Record | Target | Purpose |
| --- | ---: | --- |
| Accounts | 1,000 | Existing Accounts and Positions integration |
| Securities | 5,000 | Multiple securities per issuer; 500 are funds |
| Corporate entities | 2,000 | Shared parents and subsidiary chains |
| Account positions | About 30,000 | Overlapping exposures |
| Fund holdings | 50,000 | Weighted and nested holdings |
| Issuance and parent links | About 6,000 | Corporate aggregation |

Twenty isolated scenarios add 100 entities and 100 reference links; curated positions replace the first 20 random portfolios. Actual manifest counts are emitted by generation. The benchmark profile has 100,000 accounts and approximately three million positions; it is opt-in, not a claim of tested production capacity.

`exposure.nodes(id,name,kind,mark)` stores stable IDs, display metadata and fixed USD marks. `exposure.links(source,target,weight)` stores issuance, corporate-parent (weight 1), and fund-allocation links. `exposure.metadata` records profile, seed and valuation as-of. All links belong to that current snapshot; historical version selection is not implemented.

`Positions(accountid,security,quantity)` remains authoritative for holdings. Initial account-to-security edge weight is quantity × mark / portfolio value. Subsequent fund weights multiply along each path. Corporate-parent links group exposure and do not multiply it by ownership percentage. Direct means no fund in the contributing path. Separate paths count as separate allocations, not duplicate positions.

Account IDs start at 70000. Synthetic security IDs TX* and Z* fit inherited varchar limits. Existing accounts are unchanged; user01 receives entitlements for the seeded demonstration accounts. Additional inherited securities require analytical issuer mappings and marks before use in synthetic portfolios.
