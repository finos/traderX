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
