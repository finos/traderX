# Integrated application deployment candidate

This opt-in compiler advances Phase 2. It does not replace the retained
nineteen-deployment C3 compatibility runtime or mark S019-06 accepted. That runtime
still contains legacy application/broker routes and cannot simply receive the new
security labels and be described as the authenticated lab.

The integrated profile uses the existing limit-order workflow through the matcher
and authenticated processor. Legacy immediate trade-ticket submission and the
old public trade-service booking path are disabled, not represented as equivalent
authenticated flows. The core bundle has nine application roles and no
trade-service Deployment, Service or allowed network route.

## Composition contract

- IDEP-01: Verify local OCI manifest/config/layer bytes against their digests before
  referencing an image. Each image declares its application role, source revision,
  current source-manifest hash and private-configuration interface. These checks
  establish byte consistency, not a supplier signature or trusted build provenance.
- IDEP-02: Enumerate all protected application roles and dependencies. Refuse
  missing roles, unpinned images, ambiguous commands, inherited credential
  environment values, loopback-only listeners and missing TLS declarations.
- IDEP-03: Generate only ClusterIP Services, tokenless service accounts, non-root
  single-container Deployments, bounded resources and writable temporary/config
  mounts. No public Ingress, NodePort, host mounts or unrestricted networking.
- IDEP-04: Default-deny all pod ingress/egress. Permit only named source/destination
  flows and cluster DNS. Gateway ingress reaches the session/frontend boundary;
  application APIs and broker monitoring receive no public ingress rule.
- IDEP-05: Project only named Secret keys. Do not serialize secret values or copy
  private source files into the public bundle. Existing worker configuration
  loading requires same-UID regular 0600 files: projected Secrets cannot be passed
  directly to it. A bounded launcher materializes selected keys in a private 0700
  directory before exec. Identical restart reuses verified files; changed Secret
  bytes or unexpected files cause refusal and require a fresh pod/config volume.
- IDEP-06: Package execution migrations in dependency order, independently hashed,
  for bootstrap application before first settlement. Never apply them using an
  application database identity or silently migrate an existing lab.
- IDEP-07: Emit an admission allowlist for exact role/image pairs and restrictions
  that cover direct Pods and Deployment templates. Digest allowlisting is separate
  from the outstanding signature/provenance admission requirement.

## Inputs and execution

`integrated_deployment.py source-manifest` prints the canonical source hashes and
their aggregate digest. Build packaging must embed that digest and the intended
source revision in each OCI config label. `render --input <build-contract.json>
--output <new-directory>` verifies supplied OCI layouts and emits a Kubernetes
List, ordered SQL migration files and a review plan. `verify --input … --output …`
recompiles and compares every byte without contacting a cluster.

The input contains a separate candidate namespace, one platform, named Secret
references and OCI layout locations. Dependencies are explicit same-namespace
Services (database, broker, identity, reference-data) plus the operator-controlled
gateway and cluster DNS in named namespaces. No image is pulled or pushed.

The exact build contract has fields `schema_version: 1`, `namespace`, `platform`
(`linux/amd64` or `linux/arm64`), `source_commit`, `workloads`, `gateway` and
`dependencies`. Each of the nine `workloads` entries contains:

| Field | Required value |
| --- | --- |
| `image` | Registry reference at the actual single-platform OCI manifest digest |
| `oci_layout` | Absolute extracted OCI layout directory containing index/config/layer blobs |
| `secret` | A distinct preprovisioned Secret name for this workload |
| `keys` | Sorted, unique projected keys including `config.json`; at most sixteen keys |

Every OCI config must run as `10001:10001` and declare these labels:
`org.opencontainers.image.revision`, `traderx.security-lab.role`,
`traderx.security-lab.source-manifest` and
`traderx.security-lab.config-interface=private-config-v1`. Server images additionally
declare `traderx.security-lab.bind-address=0.0.0.0`,
`traderx.security-lab.transport=https` and their contract port. The compiler uses
the image's exact non-shell Entrypoint plus Cmd as the Kubernetes command. These
are build-interface declarations; actual listener behavior remains a live gate.

The browser and delivery roles require the private materializer in that command.
For example, the image launcher uses the following structure, with every copied
key listed in sorted order and an absolute application executable after `--`:

```text
/usr/local/bin/python /opt/traderx/private_materializer.py
  --source /run/projected --target /run/private/config
  --key ca.pem --key config.json
  -- /usr/local/bin/python /app/scripts/security-lab/browser_runtime.py
  --config /run/private/config/config.json
```

All private file references inside that configuration must point to the copied
`/run/private/config` files. A browser image also packages its immutable Angular
build at the configured static root. Other API images must implement the declared
private-config interface; the compiler does not invent their startup adapters.
Each dependency declares its exact namespace, port and verified transport; the
gateway declares its separate namespace and pod `app` label. See the compiler's
`ROLES`, `DEPS` and `EDGES` constants for the closed inventory. Do not replace a
dependency with an unreviewed public URL or broaden a denied flow to regain a
passing test.

Generated Deployments start at **zero replicas**. The plan records a required
sequence: verify ownership/resources/CNI → install policies → provision private
credentials/TLS → initialize SQL and ordered migrations → stage workloads →
validate the actual listener/configuration → activate in dependency order → run
combined positive/negative checks. An offline compiler cannot verify any live
step and provides no automatic activation command.

## Remaining acceptance

The current BrowserServer binds localhost and needs a reviewed container runner
before a ClusterIP Service can reach it. Java read APIs use finite public-key
snapshots, not dynamic JWKS/key rotation. Build recipes must supply the actual
private-config interface and service-specific audience/TLS settings; labels alone
do not prove behavior. The people-service policy is a separate candidate.

The core bundle does not replace telemetry storage/collector lifecycle, provision
the OIDC realm, configure broker accounts/subjects, install a WAF, establish image
signatures or run Kubernetes. Those dependencies and their evidence remain
explicit blockers. Complete Phase 2 only after the composed deployment passes
normal trading, authorization/broker/network/admission denials and recovery in
the same running environment. A server dry-run is an additional useful gate, not
that acceptance result.
