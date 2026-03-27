---
title: Spec Layering Model
---

# Spec Layering Model

## Baseline First

Baseline files under `TraderSpec/foundation/00-traditional-to-cloud-native/specs` capture:

- current system moving parts
- baseline functional requirements
- baseline non-functional requirements
- baseline interface contract rules

## Path Overlay Rules

## DevEx and Non-Functional Tracks

- Inherit baseline FR unchanged.
- Add step-level NFR overlays only.

## Functional Track

- Inherit baseline FR.
- Add explicit step-level FR extensions.
- Keep backward compatibility and migration notes.

## Generation Contract

For every step, generation and validation use:

1. baseline FR
2. baseline NFR
3. step spec overlay
4. contract references
