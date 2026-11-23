# Required flows

Normal: authenticate → authorize account/business operation → API → permitted NATS/SQL → worker → settled order/trade → correlated evidence.

Negative: ordinary client attempts another account or operator route; service attempts unrelated network/subject/table operation; each intended layer rejects and the authoritative outcome remains unchanged.

Residual: explicit assumed compromise → same process/client and permitted SQL connection → bounded synthetic within-grant write → independent before/after inspection → runtime comparison → reset. This hook is not proof of a real RCE or WAF bypass.
