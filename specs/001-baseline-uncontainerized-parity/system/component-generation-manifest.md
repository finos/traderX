# Component Generation Manifest

This document defines the normalized manifest contract used by TraderSpec synthesis generators.

## Purpose

The manifest is the deterministic, machine-readable bridge between Spec Kit artifacts and generated source.

It enables:

- requirements-driven generation (not direct script-authored source dumps)
- stable semantic diffs between generator revisions
- explicit traceability from generated code to requirements, stories, acceptance criteria, and verification checks

## Source Inputs

Manifest values are compiled from:

- `catalog/component-spec.csv`
- `specs/001-baseline-uncontainerized-parity/system/requirements-traceability.csv`
- `specs/001-baseline-uncontainerized-parity/components/<component-id>.md`
- `specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml` (when defined)

## Output Location

Compiled manifests are written to:

- `TraderSpec/codebase/generated-manifests/<component-id>.manifest.json`

## Required Fields

- `schemaVersion`
- `generatedAtUtc`
- `component`
- `runtime`
- `contracts`
- `traceability`
- `constraints`

## Normalized Mapping Rules

1. `component.*` is sourced from `catalog/component-spec.csv`.
2. `runtime.requiredEnv` splits `required_env` by `|`.
3. `runtime.dependsOn` splits `depends_on` by `|` and removes `none`.
4. `contracts.primary` is the mapped `contract_file` when not `none`.
5. `traceability.*` is deduplicated from matrix rows matching `component_id`.
6. `constraints.preIngressCorsRequired` is true when `SYS-NFR-001` maps to the component.

## Schema

The authoritative JSON Schema is:

- `specs/001-baseline-uncontainerized-parity/system/component-generation-manifest.schema.json`
