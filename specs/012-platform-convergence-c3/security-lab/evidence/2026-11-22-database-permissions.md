# Scoped database identities: SL-T09b

Verified on 2026-11-22 in kind-traderx-security-lab, pinned C3 snapshot.

Four application roles have no superuser/create-role/create-db/replication/BYPASSRLS
flags, memberships or public-table ownership. Live JDBC pools use lab_account,
lab_position, lab_trade_processor and lab_order_matcher; zero JDBC sessions use the
bootstrap administrator. All 140 table privilege checks match the reviewed matrix.
Each real login completes its allowed SQL operation; synthetic rows are rolled back.
Sixteen negative operations return insufficient_privilege SQLSTATE 42501.

Eighteen admission denials cover literal/cross-service credentials, environment
injection, matcher runtime DDL, protected direct-Pod bootstrap-secret references
and a literal bootstrap-password regression, with valid positive controls.
Current runtime credentials use dedicated Kubernetes Secret references. Secret
creation uses server-side apply, avoiding plaintext last-applied annotations.

The known demonstration administrator password was rotated; its replacement is
in a database-only Secret. The old password fails and the replacement succeeds
through service DNS. PostgreSQL local socket/loopback trust remains inside the
DB-server boundary, so loopback login is not accepted as password-rejection proof.
Verification deliberately connects to database:5432 under the SCRAM host rule.

Eight business, six supporting and one database process/admission checks pass.
The full inherited State 010/011/012 trading suite passes after SQL cutover and the
database restart. Private phase records, original manifests/grants and logical
checkpoint remain under runtime/database-permissions, not source control.

Limitations: no account/tenant authorization or protection against misuse within
allowed grants; bootstrap operator remains privileged. Runtime credential rotation
is SL-T09c, still pending. The account positive control advances accounts_seq once;
sequence allocation is not rolled back. SQL transport TLS and authoritative external
audit remain later work. No first-release/compliance/runtime-protection claim.

Smoke log SHA-256: `20a8a3cff394eeaaa9759a69a6258b134e2181f0da55e9f600d55fe6b5b6336b`.

Final validation: 47 unit tests, JavaScript syntax, all four repository gates and
19/19 application Deployment readiness passed. The ninth SQL experiment also passed
through the remote cookie-authenticated console with downloadable evidence.
