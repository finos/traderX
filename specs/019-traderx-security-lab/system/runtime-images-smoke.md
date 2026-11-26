# Inspected Python image smoke boundary

`verify_runtime_images.py --runtime-dir PATH --images IMAGES.json --output EVIDENCE.json`
executes only on explicitly isolated hosted Linux. The input contains a source
commit and the three `runtime_images.inspect` entries, each with a local
`runtime_reference`. Before starting any image, revalidate its OCI descriptors,
layers, source labels and exact launcher command; require Docker's loaded image
ID to equal the inspected configuration digest. Execute that immutable ID.

The browser image must start with its actual packaged Angular assets, verified
HTTPS identity trust and the fixed private-config launcher. Check `/health/ready`,
the `/trade` index and hashed JavaScript, CSP, client rejection of the server
certificate without the fixture CA, anonymous API denial and inaccessible
configuration/key paths.
The synthetic issuer supplies signing keys only. It listens on the owned internal
Docker network's gateway address; the browser port is published only on loopback.
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
Failures report only fixed stage/check identifiers, never exception text or
container logs. Only the hosted image
execution supplies runtime proof.
