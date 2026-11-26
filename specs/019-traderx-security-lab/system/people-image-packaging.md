# People-service image packaging candidate

This is preparatory tooling for S019-06a3b3, **not an accepted image or
deployment**. The protected runtime contract remains
[people-runtime.md](people-runtime.md). The existing generated .NET project has
no .NET test project. The hosted builder compiles the pinned C3-derived source,
then runs the existing real Keycloak/operator authorization campaign against the
generated DLL over its explicitly scoped loopback HTTP fixture. It subsequently
publishes without rebuilding and refuses a different published DLL. The campaign
also binds the synthetic directory asset. This is not a test of the private
launcher, image, Kestrel HTTPS, or integrated deployment.

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
inventory but excluded from the image context.

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
Each `rootfs.diff_ids` value is checked against the entire uncompressed tar
stream, including trailing blocks, with bounded decompression for gzip layers.
It also checks the fixed .NET host
and Python interpreter paths, safe root ownership and searchable parents,
permitted relative Python symlink chain, executable modes and AMD64 ELF
structure. These checks do **not** authenticate either executable or establish
base-image provenance or its dynamic dependencies. It
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

For a **future authorized hosted image gate**, use the isolated builder and
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
The recipe copies `/usr/share/dotnet` from the pinned Ubuntu chiseled runtime
onto the pinned Debian Python image; shared-library and globalization
compatibility are **not established** by these offline checks. The image is
**likely not runnable as composed**: the verified Python slim base lacks ICU,
and copying only `/usr/share/dotnet` omits the chiseled-extra ICU libraries
under `/usr/lib/x86_64-linux-gnu/libicu*.so.74*`. The launcher rejects inherited
`DOTNET_` overrides, so an invariant-mode environment toggle is not a remedy.
Microsoft's
[image documentation](https://github.com/dotnet/docs/blob/main/docs/core/docker/container-images.md)
describes `chiseled-extra` as including ICU, tzdata and C++ libraries, while
the [official Python slim Dockerfile](https://github.com/docker-library/python/blob/master/3.14/slim-bookworm/Dockerfile)
does not install ICU. Copying Ubuntu native libraries into Debian also requires
ABI review. No separately reviewed, pinned compatible library set is available
here, so no libraries are copied or installed; actual startup remains a
required hosted gate after this gap is resolved.

The projection must have Kubernetes-style `..data` generation semantics; a
plain directory of five regular files is not an equivalent fixture. The
eventual runtime must enforce read-only root, UID/GID 10001, private writable
volumes, dropped capabilities and the other restrictions in the runtime and
integrated acceptance contracts.

## Pending acceptance

Build and inspect the actual image on a disposable hosted runner, then verify
native .NET startup, TLS hostname/CA validation, operator lookup using the
packaged directory, negative authorization/trust cases, projection and
filesystem boundaries, cleanup and immutable image identity. A mocked OCI
unit test or the loopback source fixture cannot establish any of these image
properties. The existing integrated compiler has not been changed to admit this
private people adapter; integrated rollout and the broader S019-06a3 remain
separate gates. Hashes and digest pins are not signatures, provenance
attestation, vulnerability assessment or full supply-chain assurance.
