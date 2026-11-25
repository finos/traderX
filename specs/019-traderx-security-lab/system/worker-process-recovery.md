# Worker process recovery and application handoff

Run the real `delivery_worker.py` CLI as owned child processes with private
configuration and logs. Use one bounded PostgreSQL fixture and one TLS broker
on a dedicated Linux runner. Never use the laptop's active trading environment.

Acceptance requires observing a publisher blocked in SQL acknowledgment after
the broker accepted its event, killing that process, and proving a new process
reclaims its expired lease without losing the event. For the consumer, hold a
projection transaction open, kill the process, and verify rollback of inbox and
effect together. Restart with the same durable subscription and inspect final
inbox, projection and broker acknowledgment state. Also verify ordinary SIGTERM
exit and restart when no work remains. SQL gates are synthetic fault fixtures;
the process kills and broker delivery are real. This does not prove host power
loss, replicated availability or production supervision.

Follow this with an opt-in generated Angular candidate. Settlement messages
must invalidate account-scoped HTTP snapshots rather than apply untrusted
payloads to trade/position grids. Coalesce bursts, refresh on reconnect, discard
HTTP responses from an obsolete account scope, and cancel on destruction.
Notifications carry no business-write authority. HTTP authorization, browser
session/CSRF and authenticated broker credential issuance remain explicit
deployment prerequisites; source integration alone does not close them.

Generate the frontend candidate with
`python scripts/security-lab/render_application_consumers.py --output-dir /absolute/new/frontend`.
The immutable C3 baseline is the only source; overlay inputs and generated files
are hashed and an existing output directory is refused. The regular C3 state is
unchanged. Hosted CI installs its pinned frontend lockfile, runs the focused
Chrome tests against actual blotter classes and builds Angular. No new frontend
dependencies or browser downloads are required on the maintainer laptop.

The snapshot refresher allows one HTTP request at a time, coalesces pending
invalidations and caps each request at five seconds. Changing scope immediately
clears the grid and cancels the old request. Denial clears stale records.
Events never change the database or carry a durable browser acknowledgment.
The UI still uses its existing JavaScript number/display model; exact financial
decimal preservation is established only for the server-side delivery path.
Full authenticated HTTP, WebSocket identity, revocation and browser acceptance
must be tested together before deployment. The existing handwritten WebSocket
protocol parser is not replaced or certified by this candidate.

Observed checkpoint: [25 November process and application evidence](../evidence/2026-11-25-process-application-consumers.json).
The hosted campaign passes 14 actual process checks and eight Chrome component
checks, followed by an Angular production build. The browser tests use HTTP/feed
doubles; full authenticated browser acceptance remains separate. Reproduce the
process campaign on an isolated supported fixture host with:

```bash
python scripts/security-lab/verify_worker_process.py \
  --runtime-dir /absolute/private/runtime \
  --output /absolute/private/new-process-evidence.json
```
