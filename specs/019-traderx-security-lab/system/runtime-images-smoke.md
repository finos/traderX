# Inspected Python image smoke boundary

`verify_runtime_images.py --runtime-dir PATH --images IMAGES.json --output EVIDENCE.json`
executes only on explicitly isolated hosted Linux. The input contains a source
commit and the three `runtime_images.inspect` entries, each with a local
`runtime_reference`. Before starting any image, revalidate its OCI descriptors,
layers, source labels and exact launcher command. Bind Docker's loaded image ID
to the exact inspected config digest (classic store), or to the inspected
single-platform manifest digest with matching descriptor media type and byte
size (containerd store). Refuse arbitrary index targets. Execute only that
validated immutable ID and record whether it identifies config or manifest.

The browser image must start with its actual packaged Angular assets, verified
HTTPS identity trust and the fixed private-config launcher. Check `/health/ready`,
the `/trade` index and hashed JavaScript, CSP, client rejection of the server
certificate without the fixture CA, anonymous API denial and inaccessible
configuration/key paths.
The synthetic issuer supplies signing keys only. It listens on the owned internal
Docker network's gateway address. The browser requests a loopback-only port
mapping. Some Docker versions suppress publication on internal-only networks;
the verifier checks the effective mapping and records the actual probe route.
With no mapping, it connects only to the inspected address on its owned internal
network while verifying the `localhost` certificate and fixed Host header. An
effective but unreachable mapping fails; it cannot silently fall back. Direct
internal probing does not establish that a learner-facing port is available.
There is no real OIDC login or authenticated business API claim in this campaign.

All three containers use UID/GID 10001, a read-only root, dropped capabilities,
no privilege escalation and bounded CPU/memory/processes. Root-owned projected
keys have mode 0440 and group 10001, mounted read-only. The launcher materializes
them into a private tmpfs as UID 10001, files 0600 and directory 0700. Inspect the
running browser's actual identity, permissions and capability state, including
a denied root-filesystem write and tmpfs identity from `/proc/self/mountinfo`.

Each worker receives structurally valid configuration for the other worker mode.
It must exit with the fixed sanitized configuration-refusal message before
opening database/broker connections. This establishes packaging and fail-closed
role binding only; successful image-based PostgreSQL/NATS delivery remains a
separate milestone. No Kubernetes deployment, image signature or cumulative
application acceptance is established here.

Use unique ownership labels for containers/network, remove only owned resources
on success and failure, remove the temporary private fixture, and withhold raw
container output or credentials from evidence. A failed cleanup prevents a passed
result. Local unit tests mock Docker and verify digest binding, permissions,
execution arguments, role mismatch and cleanup ownership. A local loopback test
also verifies the fixture certificate chain with strict X.509 validation.
Failures report only fixed stage/check identifiers and bounded public image
digests/descriptor metadata, never exception text or container logs. Source
reinspection, loaded-metadata and identity mismatches have distinct check IDs.
Only the hosted image
execution supplies runtime proof.
