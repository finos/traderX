# Research: FDC3 Post-Trade DvP Settlement (TraderX ↔ BankerX)

## Objective

Complete the trading lifecycle beyond execution: let TraderX blotter rows dispatch standardized post-trade settlement instructions to a clearing desk through FINOS FDC3 3.0, without changing TraderX backend service contracts.

## Inputs Reviewed

- `spec.md` (016) and the `014-fdc3-intent-interoperability` transition delta
- FINOS FDC3 3.0 intent/context usage patterns; our authored `fdc3.paymentContext` context type (FINOS PR #2204)
- ISO 20022 CBPR+ message structure: pacs.008 (credit transfer initiation) → pacs.002 (payment status report, `Acsc`)
- RFC 4122 UUIDv4 UETR as the end-to-end settlement reference
- BankerX reference implementation (`synaptic-fx-terminal`): ADR-555 Alcove Runtime Guardian pre-flight, sanctions Bloom screening, solvency check, atomic settlement across the Trilateral Settlement Powerhouse (Solana Token-2022 `RequiredMemoTransfers`, XRPL Altnet DENSE-16 SHAMap, SynapticChain L1 SMR)
- state `009` blotter interaction patterns and state `012`/`014` convergence + interop baselines

## Key Decisions

1. Reuse the state-014 FDC3 adapter baseline (agent detection, listeners, graceful absence) rather than building a parallel stack.
2. Use `fdc3.raiseIntent("StartPayment", paymentContext)` as the single settlement entry point; `paymentContext` carries the full ISO 20022-adjacent payload so the clearing desk never re-keys data.
3. Bind every settlement to an RFC 4122 UUIDv4 UETR minted at dispatch time; the UETR is the join key across blotter, BankerX, and pacs.002 confirmation.
4. Keep TraderX crypto-free and under 2ms dispatch: all compliance (guardian, sanctions, solvency) runs in the BankerX tier.
5. Treat FDC3 availability as optional: identical fallback (toast + direct dispatch URI) as state-014 degraded mode.
6. Backend TraderX services unchanged; settlement state arrives back through FDC3 context listeners only.

## Risks and Mitigations

- Risk: `paymentContext` drift against the upstream FDC3 proposal.
  - Mitigation: schema pinned in `contracts/contract-delta.md`; reference flow validated by the BankerX adapter tests.
- Risk: settlement confirmations arriving for stale or duplicated dispatches.
  - Mitigation: UETR-keyed correlation; a row is only marked `SETTLED` on a matching-UETR `Acsc`.
- Risk: long settlement latency masks UI failures.
  - Mitigation: structured diagnostic logging of `IntentResolution` (target app, status) so operators can trace dispatches (FR-01604).
- Risk: non-conformant payloads rejected by CBPR+ validation downstream.
  - Mitigation: field-level validation at context-build time (amount/currency/pair/rate/debtor/creditor present and well-formed).
- Risk: partial rail availability in the trilateral settlement topology.
  - Mitigation: `networkRouting` declares the routing preference; BankerX performs pre-flight before any dispatch is acknowledged.