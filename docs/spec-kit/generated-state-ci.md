---
title: Generated State CI Policy
---

# Generated State CI Policy

This document defines the CI contract for generated TraderX code branches.

## Scope

- Security and license CI is required for all generated states from `002+`.
- Container image build/publish CI is required for convergence states from `C1+`.

## Required CI For States `002+`

Each generated `code/generated-state-*` branch must include CI workflows for dependency security and license scanning:

- `.github/workflows/security.yml`
- `.github/workflows/license-scanning-node.yml` (required when the state contains Node.js components)

These workflows must cover every applicable component in the generated state:

- Java/Gradle components in Gradle scan jobs
- .NET components in .NET scan jobs
- Node.js components in Node scan and license jobs
- containerized components in container vulnerability scan jobs

Coverage must be derived from generated component manifests/catalog data, not a manually maintained static list.

## Node License Requirement

All generated Node.js projects must declare:

```json
"license": "Apache-2.0"
```

Policy:

- Any new Node.js project introduced by a state transition must include this license field in its generated `package.json`.
- License scanning workflows should fail when a generated Node.js project omits this declaration.

## CVE Suppression Contract

Generated branches must carry the CVE suppression files used by security scanning:

- `.github/gradle-cve-ignore-list.xml`
- `.github/node-cve-ignore-list.xml`
- `.github/dotnet-cve-ignore-list.xml`

Policy:

- Keep a baseline suppression set shared across generated states.
- Allow state-specific suppression deltas when dependency sets diverge.
- When a state changes dependencies, update scanner coverage and suppression files in the same change.

## Convergence CI For `C1+`

Each convergence state from `C1+` must include:

- `.github/workflows/build-and-publish.yml`

The workflow must build and publish all containerized components present in that convergence state to GHCR.

## GHCR Namespace Policy For Convergence States

Use convergence-level namespaces (not numeric state ids):

- `C1`: `ghcr.io/finos/traderx-c1/<component>`
- `C2`: `ghcr.io/finos/traderx-c2/<component>`
- `C3`: `ghcr.io/finos/traderx-c3/<component>`

Each image publish must include:

- immutable tag: commit SHA
- moving tag: `latest`

## State Run Bundle Requirement For `C1+`

Each convergence state from `C1+` must publish a generated run bundle for consuming GHCR images without local source builds.

Minimum bundle artifacts:

- runtime manifest(s) that reference published GHCR images
- `.env.example` or equivalent runtime config template
- state run README with copyable startup commands

## Local CI Preflight Before Publish

Before publishing generated branches, run local CI preflight checks:

```bash
# workflow lint
actionlint

# workflow smoke execution (best-effort parity with GitHub-hosted runners)
act -W .github/workflows/security.yml
act -W .github/workflows/license-scanning-node.yml

# required for convergence states C1+
act -W .github/workflows/build-and-publish.yml
```

Also run the underlying scan/build commands directly via project scripts where available, so local and CI behavior stay aligned.

## Publish Gate

Generated branch publish is blocked unless:

- required CI workflows are present for the target state,
- scanner/build matrices include all applicable components,
- required suppression files are present and valid,
- local preflight checks pass.
