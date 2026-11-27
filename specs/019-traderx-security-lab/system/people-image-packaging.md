# People-service image packaging and bounded acceptance

S019-06a3b3 passes **43 actual-image checks** at `8f1b6fe9`; see the
[recorded evidence](../evidence/2026-11-27-people-image.json). This accepts the
private image interface, not the combined deployment or a supported-runtime
release. The protected runtime contract remains
[people-runtime.md](people-runtime.md). The existing generated .NET project has
no .NET test project. The hosted builder compiles the pinned C3-derived source,
then runs the existing real Keycloak/operator authorization campaign against the
generated DLL over its explicitly scoped loopback HTTP fixture. It subsequently
publishes without rebuilding and refuses a different published DLL. The campaign
also binds the synthetic directory asset. That build fixture is distinct from
the subsequent actual-image campaign described below, which tests the private
launcher, Kestrel HTTPS and operator directory behavior.

## CLI and evidence

Run only on an isolated hosted Linux runner with the fixture's prerequisites,
including Docker, Keycloak, browser tooling, a selected .NET 9 SDK and adequate
resources. The selected `dotnet --version` must be a stable `9.0.xxx` SDK;
installing SDK 9 alongside a newer default SDK is not enough. The build helper
requires `GITHUB_ACTIONS=true` and `TRADERX_LAB_ISOLATED_LINUX=1`; the former is
normally set by GitHub Actions.
The helper uses an operation lock and fresh paths; it may create fixture
containers and a private fixture log. It must not be run on a shared user
environment. Build/publish stdout and stderr are discarded; errors are bounded
generic messages. The fixture controls and cleans up its own resources.

```bash
TRADERX_LAB_ISOLATED_LINUX=1 python3 scripts/security-lab/build_people_image.py --runtime-dir /absolute/fresh-runtime
python3 scripts/security-lab/people_images.py prepare \
  --generated-root /absolute/fresh-runtime/people-service \
  --publish-dir /absolute/fresh-runtime/people-publish \
  --build-report /absolute/fresh-runtime/people-build.json \
  --source-commit FULL_40_HEX_COMMIT --output /absolute/new-context
python3 scripts/security-lab/people_images.py inspect \
  --generated-root /absolute/fresh-runtime/people-service \
  --publish-dir /absolute/fresh-runtime/people-publish \
  --build-report /absolute/fresh-runtime/people-build.json \
  --source-commit FULL_40_HEX_COMMIT --layout /absolute/oci-layout \
  --name local/people-service:candidate
```

`people-build.json` schema version 1 records the selected SDK, canonical generation and
repository source-manifest hashes, the tested DLL and directory hashes, the
full publish inventory, the selected packaged files and the actual loopback
fixture result. The builder writes it only after successful compilation,
campaign and publish. Verification re-renders from C3, rejects changed or extra
source and publish inputs, re-hashes the tested DLL/asset and enforces exact
bytewise equality of the published and tested DLL and managed dependency
inventories, deps.json and runtimeconfig.json. The DLL inventory must match the
runtime entries of deps.json; unreviewed native or runtime-specific dependencies
are rejected. The complete ordered fixture check list must match the current
campaign, including its repeated labels. The report's fixture checks are consistency records,
**not cryptographic attestations**: a person able to replace reports and
artifacts can fabricate them. The revision is an explicit caller-supplied label;
the content hashes do not independently authenticate that revision.
The Web SDK's `web.config`, when present, is hashed in the full publish
inventory but excluded from the image context. The empty static-assets manifest
must have exactly `Version: 1`, no endpoints and the SDK
`ManifestType: Build` → `Publish` transition; all other runtime metadata and
assembly bytes remain identical. The published manifest bytes stay hash-bound.

`prepare` writes a new offline context and `image-build.json` with the context
hashes, source/report hashes, pinned bases, command and projection inventory.
It does not build, pull or publish. `inspect` reads an already exported
single-platform OCI layout, validates its descriptors and actual application
bytes, exact inventory, ownership, file modes, searchable root-owned parents,
user, command, working directory, environment and role/interface labels. Layer
whiteouts remove only lower-layer entries; entries or whiteouts traversing any
tracked symlink ancestor are refused, including outside the application tree.
Tracked paths and symlinks use bounded descendant indexes; whiteouts and
replacements remove only indexed subtrees rather than scanning unrelated paths.
Each index permits at most 200,000 paths and one million ancestor references;
OCI entry and hardlink paths are limited to 4,096 characters and 256 components.
Both indexes and the current layer's recorded path/link names share a
conservative 32 MiB aggregate budget for their UTF-8 bytes; duplicate ancestor
strings are counted again. Hardlinks involving the application tree, .NET runtime tree, or tracked
Python executable paths are refused, including symlink-mediated aliases.
Each `rootfs.diff_ids` value is checked against the entire uncompressed tar
stream, including trailing blocks, with bounded decompression for gzip layers.
It also checks the fixed .NET host
and Python interpreter paths, safe root ownership and searchable parents,
permitted relative Python symlink chain, executable modes and AMD64 ELF
structure. The five native library destinations must be root-owned regular
`0444` AMD64 ELF shared objects with searchable root-owned parents; their
presence and structure do not authenticate their bytes or prove their ABI.
The image label and `image-build.json` bind the canonical people runtime lock
hash independently of the shared source manifest. These checks do **not**
authenticate either executable or establish base-image provenance or dynamic
dependency closure. It
returns the immutable manifest reference and required private keys; it does not
load an image or run it. The verified Python base and existing BuildKit lock
remain in `runtime-images.lock.json`; the separate .NET runtime lock records the
verified AMD64 manifest and index. Registry config retrieval failed, so no
config digest or inferred base configuration is claimed.
The project currently targets .NET 9, which reached end of Microsoft support
on 10 November 2026; this pin is not a security-support claim. Migration to a
supported runtime remains a separate prerequisite for a supported deployment.

The build report has fields `schema_version`, `service`, `status`,
`source_manifest` (`files` and `sha256`), `dotnet_sdk`, `generation_sha256`,
`assembly_sha256`, `directory_sha256`, `publish_files`, `publish_inventory`,
and `fixture` (the existing campaign's `status`, `scope`, `checks`,
`directory_sha256`, `assembly_sha256`, and `limitations`). Both publish maps
are relative paths to SHA-256 values; `publish_files` is the packaged managed
subset. `inspect` returns exactly `image` (the supplied name plus verified
manifest digest), `oci_layout` (absolute directory), `secret`
(`private-people-service`) and sorted `keys`. Neither result is runtime
acceptance evidence.

For the **hosted image gate**, use the isolated builder and
pinned BuildKit reference described in [runtime-images.md](runtime-images.md).
With an already created uniquely named `$OWNED_BUILDER`, a new context and a
fresh output path, the export shape is:

```bash
docker buildx build --builder "$OWNED_BUILDER" --platform linux/amd64 \
  --network none --provenance=false \
  --output type=oci,oci-mediatypes=true,dest="$WORK/people.oci.tar" \
  "$WORK/people-context"
```

Both base images may be pulled by BuildKit by their pinned manifest digests;
build steps have no network. Do not push. Safely extract the OCI tar into a
fresh directory, invoke `inspect` as above, and remove only the owned builder
afterward. A separate local Docker export may be needed for later runtime
acceptance; do not treat it as equivalent to OCI inspection.

Only managed publish assemblies, runtime metadata, the verified synthetic
`MockDirectory/people.json`, `people_runtime.py`, and `private_materializer.py`
are copied into `/opt/traderx`. The executable is the fixed private launcher;
it rejects inherited .NET/application overrides, materializes the five
projected keys, then invokes the fixed DLL with the private content root.
The image inspector additionally refuses unreviewed inherited Python, loader,
application or other environment variables. Any base environment outside the
reviewed allowlist fails closed and needs separate review, not a bypass.
The runtime composition uses the pinned Linux/AMD64 Microsoft ASP.NET
`9.0-bookworm-slim` manifest and the existing Python `slim-bookworm` manifest.
The final stage is the Python base, so it does not inherit the .NET base image's
`DOTNET_` or `ASPNETCORE_` variables. From the pinned .NET stage it copies
`/usr/share/dotnet` and exactly these native library files:

| Source in the .NET image | Destination under `/usr/lib/x86_64-linux-gnu` |
| --- | --- |
| `/usr/lib/x86_64-linux-gnu/libicudata.so.72.1` | `libicudata.so.72` |
| `/usr/lib/x86_64-linux-gnu/libicui18n.so.72.1` | `libicui18n.so.72` |
| `/usr/lib/x86_64-linux-gnu/libicuuc.so.72.1` | `libicuuc.so.72` |
| `/usr/lib/x86_64-linux-gnu/libstdc++.so.6.0.30` | `libstdc++.so.6` |
| `/lib/x86_64-linux-gnu/libgcc_s.so.1` | `libgcc_s.so.1` |

Inherited entries at those exact destinations are removed before copying, so
BuildKit cannot preserve a base-image symlink. The pinned libraries are copied
as regular `0444` files with the runtime sonames as destinations. No network package install, invariant
globalization override or floating image is used. The pinned
[Microsoft runtime-deps Dockerfile](https://github.com/dotnet/dotnet-docker/blob/a2831a5c5f6fe48f413a0840b207488d1ecd8903/src/runtime-deps/9.0/bookworm-slim/amd64/Dockerfile)
lists `libicu72`, `libstdc++6`, `libgcc-s1`, libc and OpenSSL. The Debian
bookworm/AMD64 package files in the
[ICU](https://deb.debian.org/debian/pool/main/i/icu/) and
[GCC 12](https://deb.debian.org/debian/pool/main/g/gcc-12/) pools identify
the listed library paths. This metadata review is not an inspection of the
pinned image layers: if an expected path is absent, BuildKit must fail.
Both bases use Debian Bookworm. The accepted hosted campaign exercises native
globalization and the actual application HTTPS/operator path; it is not an
exhaustive comparison of package patch levels or native dependency closure.

The projection must have Kubernetes-style `..data` generation semantics; a
plain directory of five regular files is not an equivalent fixture. The
runtime must enforce read-only root, UID/GID 10001, private writable
volumes, dropped capabilities and the other restrictions in the runtime and
integrated acceptance contracts.

## Accepted checkpoint and remaining gates

The hosted campaign runs the unchanged image entrypoint with the exact five-key
projection, proves native culture operations independently, verifies TLS and all
three operator routes, rejects ordinary identities, and tests trust expiry,
restart, private files and owned cleanup. The launcher provides a checked private
home for .NET certificate-store lookup; it does not inherit a host home or bypass
TLS validation. The compiler now aligns the people command, key inventory and
private writable mount with that interface, but retains zero replicas.

Real support-service provisioning, Kubernetes volume/CNI behavior, full
integration and supported-runtime migration remain open. Hashes and digest pins
are not signatures, provenance attestation, vulnerability assessment or full
supply-chain assurance. Those separate release requirements are not waived.

## Hosted actual-image campaign contract

The `people-image` workflow scope builds the canonical tested application,
revalidates actual OCI bytes, and runs the inspected immutable image on an owned
internal-only bridge. The API must operate with 256 MiB, UID/GID 10001, read-only
root, private tmpfs, exact five-key Kubernetes-style projection and no host port.
Client TLS CA/hostname rejection, exact operator directory results, user/claim
scope denials, bounded queries, unavailable routes/mutations, unchanged packaged
directory, trust expiry and actual same-image restart must pass. Startup alone is
insufficient because the directory service is instantiated lazily.

A separate fixed `PeopleNativeProbe.dll`, built without package sources and
mounted read-only into the same immutable image, tests Turkish casing and French
decimal formatting. Its source/artifacts/report are verified before execution;
it is not the application launcher and its success is not application acceptance.
The application is tested separately without changing its entrypoint or private
configuration contract. Only bounded booleans and hashes enter native evidence.

This is an inherited C3/.NET 9 compatibility checkpoint. S019-06a3b3r requires
migration to a supported runtime and identical regression before release. A
passing compatibility campaign does not waive that requirement or accept the
combined deployment. Runtime resource limits are observed configuration, not
throughput or tail-latency measurements.
