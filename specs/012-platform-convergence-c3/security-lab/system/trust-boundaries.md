# Trust boundaries and initial inventory

The pinned snapshot is authoritative for reference observations. Run the inventory command for file hashes, all Deployment identities/resources/security settings, Service exposure and edge routes. Environment credential values are deliberately excluded from output.

| Boundary | Reference observation | Required profile boundary |
| --- | --- | --- |
| Client → edge | HTTP proxy exposes APIs, NATS WebSocket, Grafana, Prometheus and API explorer | TLS inspection, identity, rate/size limits, separate operator routes; no bypass |
| Edge → APIs | Routing does not establish account authorization | Validated caller identity and server-side role/account checks |
| Browser → NATS | Config contains `no_tls: true` and no authentication stanza | Protected transport and short-lived broker credentials scoped to exact account subjects |
| APIs/workers → DB | Runtime uses shared demonstration identity; bootstrap uses same identity | Non-admin service grants, separate bootstrap role, rotation, independent audit |
| Workload → cluster | Sampled manifests omit dedicated accounts/token suppression and security contexts | Restricted pods plus explicit token/volume/resource configuration and admission |
| Workload → network | Base manifests contain no NetworkPolicy | Enforcing CNI and default deny with tested directed allowances |
| Workload → evidence | Application-local logs alone are insufficient | Collector/storage credentials unavailable to compromised application |

`flows.json` is an explicit candidate flow contract derived from canonical state-010 environment dependencies and application routes inherited by C3. It is not a complete observed graph. Telemetry, probe behavior, DNS topology, gateway namespace and browser authentication must be resolved in compatibility testing. Generated policies permit both ends of each listed flow and constrain the destination port. They do not permit arbitrary Internet egress, cluster API access or operator routes.

Subject contract remains [C3 messaging map](../../system/messaging-subject-map.md). Market data uses `pricing.<TICKER>`; account streams use literal `/accounts/<accountId>/trades`, `/positions` and `/orders` suffixes. NATS token wildcards do not segment slashes. Enumerate exact subjects for authorized synthetic accounts or propose a separately reviewed contract migration. Never embed service credentials in the frontend. Browser publishing must be denied explicitly; an empty allow list is not an adequate deny-all configuration.

Network permissions do not distinguish authorized from unauthorized SQL on an allowed connection. A compromised application can invent caller context it controls. The DB canary tests this limitation without claiming that a generic runtime policy necessarily misses or prevents it.
