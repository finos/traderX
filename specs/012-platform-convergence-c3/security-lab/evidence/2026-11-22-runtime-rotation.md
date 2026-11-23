# Runtime credential rotation: SL-T09c

Position-service/lab_position was rotated in the isolated C3 lab on 2026-11-22.
The original credential passed before mutation. After ALTER ROLE, a new connection
using the retired password failed against database service DNS under SCRAM auth;
the replacement succeeded. Ten original JDBC sessions remained established.

The dedicated Secret was updated and only position-service was restarted. The new
Pod UID differs, all original backend PID/start-time identities drained, and new
lab_position JDBC sessions were observed. SQL permissions and the full inherited
State 010/011/012 trading smoke suite passed after rotation. Current verification
again rejects the retired credential; the console does not rotate on every run.

The ledger and credentials are private mode-0600 files. Public evidence is an
explicit allowlist, tested to exclude credentials and unexpected private fields.
Resume reuses the recorded replacement, not a fresh credential. Completed execution
is a no-op and can regenerate only its sanitized public record. No database data
restore or rollback-to-old-password took place.

Limits: password change alone does not revoke established sessions. No-surge Pod
replacement may briefly interrupt position reads; this is not zero-downtime proof.
Only one runtime identity was rotated. Evidence is historical/local and mutable.
The known bootstrap password was retired in the previous, separate exercise.

Validation: 49 unit tests and full SQL/trading suites passed. Browser gateway and
ngrok endpoint remain running; the SQL console includes rotation evidence.

All four repository gates passed; all 19 application Deployments are ready.
Remote authenticated SQL run `76d49be2-837c-47f1-aff6-b75b4f15561c` passed with rotation evidence
and evidence download verified. NATS remains specified, not enabled on live C3.
