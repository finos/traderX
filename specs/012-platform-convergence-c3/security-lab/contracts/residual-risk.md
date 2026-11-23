# Residual-risk experiments after the hardened baseline

Status: specified, not executed. No successful exploit, bypass or product limitation
is claimed. Each scenario requires the stated controls to be verified in the same
run; an absent control makes the hardened comparison inconclusive.

## Learning objective

Explain why a blocked entry point, restricted process, permitted connection and
least-privilege service identity can coexist with remaining harmful authority.
Measure an actual synthetic effect, then determine what additional boundary can
prevent it without disrupting legitimate trading.

| Scenario | Controls held constant | Hypothesis and decisive evidence |
| --- | --- | --- |
| RR-01: Misuse a permitted SQL write | Verified gateway, identity, workload restrictions, enforced permitted DB flow and scoped runtime SQL role | An assumed-compromised service may alter a dedicated canary inside its grants but outside the initiating user's business permission. Observe the record before/after through an independent reader; repeat an outside-grant write that must fail. |
| RR-02: Forge a permitted account event | Verified broker authentication/ACLs and permitted service identity | Subject permission may allow an event whose business content is invalid. Use a dedicated synthetic subject and recording consumer; test whether schema, transaction correlation or business invariants reject it and whether any downstream canary changes. |
| RR-03: Replay a previously permitted command | Verified identity, broker authorization and fixed synthetic workload | Transport authorization alone may not establish freshness/idempotency. Replay only against an isolated synthetic consumer, count committed effects after settlement and verify a fresh legitimate operation. |
| RR-04: Misuse an allowed outbound channel | Verified default deny plus one specifically permitted internal test collector | Destination allowlisting may permit data sent over that legitimate channel. Use only a designated synthetic marker and internal collector; record receipt and independently test a denied destination. No real secrets or public exfiltration endpoint. |

RR-01 is the first implementation priority. RR-02–04 are optional follow-on
hypotheses, not a requirement to construct successful attacks. A verified block is
an equally valid result. Do not weaken grants or add broad networking to manufacture
success. If a later control removes the effect, credit that actual boundary.

## Two distinct entry conditions

**Assumed compromise:** an explicitly enabled fixture calls a bounded operation
inside the tested process, using its existing client/connection. This establishes
what that process can do after compromise. It does not establish how an attacker
obtained execution, defeated OIDC, bypassed a WAF, or exploited TraderX remotely.

**Verified CVE:** a separately pinned vulnerable fixture and harmless reproducer
establish a specific reachable vulnerability. Compare upstream fixed and OSERA
backpatch artifacts with the same regression test under the CVE contract. A scanner
match, an HTTP 200, or a WAF rule match alone is not exploitation evidence.

## Required run sequence

1. Pin the deployment/profile and assert every control prerequisite; record partial
   baseline checks as such. Seed designated canaries and record initial state.
2. Run legitimate trading and the paired outside-permission denial. Abort effect
   claims if either control fails or the target is unreachable.
3. Execute one fixed assumed-compromise action or separately verified CVE probe.
   Expose no arbitrary command, SQL, payload or target input through the console.
4. Wait for declared asynchronous settlement bounds. Collect independent database
   state, accepted/processed messages, runtime decisions and application availability.
5. Classify allowed-with-effect, blocked-before-effect, detected-after-effect,
   contained-after-effect, failed-test or inconclusive. A killed process is not proof
   that a write or asynchronous effect was prevented.
6. Reset from the known synthetic dataset and verify legitimate trading. Repeat the
   reset/run cycle twice before accepting reproducibility.
7. Compare observation/enforcement/candidate protection with the same baseline and
   scenario. Record hooks/rules/training, false blocks, latency and recovery cost.

The compromised workload cannot write the authoritative evidence copy. Keep
privileged reset/collection identities outside its boundary. Local mutable console
records are useful during development but do not yet satisfy that acceptance gate.
Fixtures stay opt-in and isolated, with no direct ngrok route. Publicly reachable
console actions remain fixed internal tests with sanitized evidence.
