# Collector isolation and namespace Baseline — 22 November 2026

SL-T07e is complete. The application namespace now enforces Baseline v1.35 for
all Pod names and identities. The root log collector moved to its own infrastructure
namespace with fail-closed, pinned-configuration admission. This does not complete
SL-T07b or establish namespace-wide Restricted admission.

## Cutover and preservation

Fresh synthetic log markers reached Loki before cutover and after the old collector
and its Pods were removed. The original checkpoint directory was archived privately
outside source control with mode 0600. The new collector starts fresh offsets;
duplicate replay is possible. Loki, Grafana, Prometheus and Tempo kept the same
running Pods and their existing container-layer histories. None was restarted.
The original collector's application-namespace RBAC binding was removed only after
post-cutover delivery succeeded. Repeating the completed cutover was verified as
a no-op. An interrupted/failing-cutover recovery drill has not been performed.

## Enforcement evidence

Browser run `e3479b78-b12a-4b5e-a168-156a29eb94e8` passed; the downloaded evidence
payload's artifact hash was checked. Eight unrelated-name/default-identity Pod
variants were rejected by Pod Security Admission baseline:v1.35: privileged mode,
host network/PID/IPC, hostPath, added SYS_ADMIN, unconfined seccomp and hostPort.
A compliant Pod dry-run passed. A root/writable-root Pod dry-run also passed,
explicitly demonstrating that Baseline is not Restricted.

Thirteen collector variations were rejected by the infrastructure policy: broadened
host path, writable host logs, privileged mode, capabilities, writable root, default
identity, another image, shell command, extra container, longer-lived token, host
networking, secret volume and ephemeral debug container. A conforming collector
Pod dry-run passed. No unsafe Pod or debug container was launched.

The actual collector process has UID 0 as its documented exception, zero effective
capabilities, no-new-privileges, seccomp mode 2 and read-only root. Its host-log mount
is read-only. Automatic token mounting is disabled; a bounded explicit projected
token enables API discovery. Its identity can read pods/nodes/namespaces but cannot
read Secrets or create Pods/Deployments or update Namespaces/ConfigMaps in the tested
application namespace. Pod reads include full specifications, not just metadata.

The first writable-host negative was denied fail-closed due to an omitted false
field; the expression was corrected to handle that omission explicitly. Final
denials are attributed to the intended named policy and reason, with no CEL type
warnings. A fresh marker reached Loki during the final browser experiment too.

## Regression and remaining scope

Business, supporting and database workload verifiers all passed after cutover.
The complete C3 trading/settlement, APIs, UI and observability smoke passed. Its
collector readiness check now targets the infrastructure namespace through the lab
wrapper; original states retain their original namespace default. Regression tests
cover both behaviors. All 39 automated tests and all four repository gates passed.

Four stores still need history-preserving migrations: Grafana, Prometheus, Loki and
Tempo. Fifteen application workloads retain their earlier tested process restrictions;
the collector is a separately constrained root/host-log/token exception. Baseline
allows root and writable roots generally. The host log directory contains other
node Pod logs: the namespace filter is collection scope, not confidentiality against
a compromised collector. Namespace-wide Restricted, scoped DB/NATS permissions,
identity, integrated gateway/WAF, networking and runtime evaluation remain open.

[Structured verification](2026-11-22-collector-result.json) and
[cutover observations](2026-11-22-collector-cutover.json).
Trading log: `/private/tmp/traderx-security-runtime/evidence/collector-trading.log`.
SHA-256: `1f6bc9ffc32b0ffaa6c13a1015fef5e12c08d9b55be1ebbb06bcd1b3ad19694c`.
