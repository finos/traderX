# Browser notification mediation

This opt-in Phase 1 candidate replaces the inherited anonymous browser NATS
connection with a same-origin, read-only notification poll. The browser keeps its
opaque HttpOnly session cookie. Broker passwords remain in the session service.
It is **mediated broker access**, not browser NATS credential issuance.

## Requirements

- BBR-01: `/events` requires a verified, unexpired browser session and a trusted
  server-side subject-to-account grant. No query, header or event payload can
  grant an account. Unknown subjects fail closed.
- BBR-02: Each configured account uses a distinct NATS identity over verified
  TLS. That identity can subscribe only to its two settlement subjects and has
  no publish rights. Broker administration, other accounts and execution subjects
  remain inaccessible. Native NATS ports are not browser endpoints.
- BBR-03: Validate canonical event envelopes and actual subjects before copying
  only identity/account/kind/sequence metadata to bounded buffers. Notifications
  invalidate HTTP snapshots; no business values, credentials or bearer tokens
  enter the browser feed.
- BBR-04: Bind each session to the policy revision observed on its first poll.
  Revocation or any subsequent scope change retires that browser session. This
  proves broker-policy/session revocation, not live entitlement reload in every
  Spring API or provider-wide token revocation.
- BBR-05: Broker disconnects fail closed. Reconnection, process restart, stale
  cursor or buffer overflow require a fresh HTTP snapshot. This feed is a bounded
  notification cache, not a durable consumer or authoritative trade ledger.
- BBR-06: Keep one poll in flight, bounded response size and retry delay, and stop
  polling when the session expires, signs out or is denied. Never fall back to
  anonymous WebSockets. Clear account views on feed authorization denial.

## Wire contract

`GET /events` starts at the current cursor and requests a snapshot reset.
`GET /events?after=<opaque-epoch>:<sequence>` returns a bounded page:

```json
{"cursor":"opaque-epoch:12","reset":false,"events":[{"topic":"/accounts/62654/trades","eventId":"00000000-0000-4000-8000-000000000001:trade","executionId":"00000000-0000-4000-8000-000000000001","eventSequence":1,"eventKind":"trade.settled","accountId":62654}]}
```

The epoch is random per subject/policy/cache generation. The sequence is local
to that subject's cache; it exposes no other account's traffic count. An initial,
obsolete or overrun cursor returns `reset: true` and no historical payloads.
Unknown query keys, duplicate cursors and malformed cursors are rejected.

## Learning and acceptance

The hosted campaign must demonstrate ordinary authorized notifications, broker
denial of cross-account subscriptions and publication by a reader, no business
payload values in responses, invalid envelope rejection, overflow/reset,
disconnect/reconnect refresh, logout/expired-cookie denial and server-owned
policy revocation. Real broker tests and Angular HTTP-double tests are separate
proofs. Full gateway/deployment and cumulative trading acceptance remain open
until the parent Phase 1/2 campaign combines them.
