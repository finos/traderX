# Integrated application deployment candidate

This opt-in compiler advances Phase 2. It does not replace the retained
nineteen-deployment C3 compatibility runtime or mark S019-06 accepted. That runtime
still contains legacy application/broker routes and cannot simply receive the new
security labels and be described as the authenticated lab.

The integrated profile uses the existing limit-order workflow through the matcher
and authenticated processor. Legacy immediate trade-ticket submission and the
old public trade-service booking path are disabled, not represented as equivalent
authenticated flows. The core bundle has eight application roles and no
trade-service Deployment, Service or allowed network route.

The session runtime serves the Angular build itself. There is no redundant
frontend Deployment or direct gateway-to-frontend bypass. Its approved HTTP
backends are account/position/matcher plus reference-data `/stocks` and
price-publisher `/prices`; identity and NATS remain separate server-side flows.
People-service has no public session route or ingress allow rule until an explicit
operator entrypoint is provisioned. Account-to-people validation occurs only in
the disabled membership write path, so that network edge is omitted. The matcher
retains direct SQL, processor, issuer and NATS access; its old account/reference
edges are unnecessary. Pricing arrives through its authenticated NATS subscriber;
the inherited price-service URL is metadata, not an HTTP dependency.

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
  flows and cluster DNS. Gateway ingress reaches the session/static-frontend boundary;
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
- IDEP-08: Validate generated resources against a pinned real Kubernetes API on an
  isolated hosted runner. Wait for each admission policy's current-generation CEL
  type-check result, require no warnings, and prove positive/negative admission
  including the ephemeral-container subresource. Synthetic OCI fixtures must be
  clearly identified and never scheduled or represented as application builds.

## Inputs and execution

`integrated_deployment.py source-manifest` prints the canonical source hashes and
their aggregate digest. Build packaging must embed that digest and the intended
source revision in each OCI config label. `render --input <build-contract.json>
--output <new-directory>` verifies supplied OCI layouts and emits a Kubernetes
List, ordered SQL migration files and a review plan. `verify --input … --output …`
recompiles and compares every byte without contacting a cluster.

The input contains a separate candidate namespace, one platform, named Secret
references and OCI layout locations. Dependencies are explicit same-namespace
Services (database, broker, identity, reference-data, price-publisher) plus the operator-controlled
gateway and cluster DNS in named namespaces. No image is pulled or pushed.

The exact build contract has fields `schema_version: 1`, `namespace`, `platform`
(`linux/amd64` or `linux/arm64`), `source_commit`, `workloads`, `gateway` and
`dependencies`. Each of the eight `workloads` entries contains:

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

## Hosted API schema and admission gate

`verify_integrated_admission.py` is a bounded bridge between offline compilation
and application deployment. It requires an isolated GitHub Linux AMD64 runner,
Python 3.11 or later, Docker with an empty running-container inventory, at least
4 GiB available host memory and 6 GiB free disk. It uses only Python's standard
library. It rejects ordinary laptop execution before contacting Docker.

The runner verifies the downloaded kind executable against
[`admission-tools.lock.json`](admission-tools.lock.json), then creates a uniquely
named single-node cluster using the pinned Kubernetes v1.35.0 image. The node is
limited to 3 GiB RAM and two CPUs after kind initialization. No other lab cluster
is started. It accesses the API using kubectl inside its owned node; no host
kubeconfig or installed kubectl is used. The official pin sources are the
[kind release](https://github.com/kubernetes-sigs/kind/releases/tag/v0.31.0) and
[Linux AMD64 checksum](https://github.com/kubernetes-sigs/kind/releases/download/v0.31.0/kind-linux-amd64.sha256sum).

The parent workflow downloads and verifies that binary in its own job, then runs:

```bash
TRADERX_LAB_ISOLATED_LINUX=1 python scripts/security-lab/verify_integrated_admission.py \
  --kind "$RUNNER_TEMP/kind-v0.31.0" \
  --runtime-dir "$RUNNER_TEMP/traderx-admission" \
  --output "$RUNNER_TEMP/traderx-admission-evidence.json"
```

No local execution or image download is required to prepare this gate. Its
`admission_fixture.py` creates valid OCI metadata with empty tar layers and an
explicit `admission-only-non-runnable` label. All references use `example.invalid`;
they are not pushed, imported, pulled or described as protected application
builds. The normal compiler verifies those fixture bytes and emits the same
policy/manifests it would emit for a verified build contract.

The campaign checks:

1. Both policies pass API schema validation and the current-generation
   [CEL type-check status](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/),
   without expression warnings. Binding readiness is confirmed by a real denial.
2. Every Service and NetworkPolicy passes server schema validation, and approved
   Pods and Deployments for all eight roles pass server-side dry-run admission.
3. Altered image, command, service account, private Secret, optional Secret,
   API-token mounting, writable root filesystem and resource profile are denied
   for both a Pod and a Deployment. The denial must identify the intended policy;
   unrelated API errors cannot count as control evidence.
4. The ephemeral-container update endpoint rejects an added debugger. Its target
   is the sole persisted application-shaped Pod, protected by a scheduling gate
   and a nonexistent scheduler. It must have no assigned node, container status
   or accepted ephemeral container. The Pod is deleted even when that check fails.
5. No application Pod or Deployment remains, and the owned kind cluster is
   removed before success evidence is written.

JSON evidence records the source hashes, tool/node pins and individual check
results. Progress is sent to stderr so stdout remains machine-readable JSON.
Offline unit tests exercise orchestration, attribution and cleanup, not Kubernetes
semantics. Only a successful hosted campaign establishes the stated API results.
Kind's default network is sufficient for this schema/admission gate; it provides
**no evidence of NetworkPolicy enforcement**, TLS, application readiness, image
signature trust, trading or end-to-end State 019 acceptance.

## Remaining acceptance

The browser image must package the reviewed `browser_runtime.py` runner with an
explicit `0.0.0.0` listener and its Angular static build. The generated TCP probe
proves only that a socket accepts connections. Application acceptance must use
verified HTTPS `/health/ready` with the exact configured public-origin Host
header and CA. The public browser origin and OIDC issuer must also be reachable
consistently from the browser and private services; a private Keycloak URL alone
does not establish this configuration.

Java read APIs use finite public-key snapshots, not dynamic JWKS/key rotation.
Build recipes must supply the actual private-config interface and service-specific
audience/TLS settings; labels alone do not prove behavior. The people-service
policy is a separate operator candidate with no default ingress grant.

The core bundle does not replace telemetry storage/collector lifecycle, provision
the OIDC realm, configure broker accounts/subjects, install a WAF, establish image
signatures or run Kubernetes. Those dependencies and their evidence remain
explicit blockers. Complete Phase 2 only after the composed deployment passes
normal trading, authorization/broker/network/admission denials and recovery in
the same running environment. A server dry-run is an additional useful gate, not
that acceptance result.
