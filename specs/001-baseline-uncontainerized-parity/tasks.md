---

description: "Tasks for root-level Spec Kit simple app baseline adoption"
---

# Tasks: Simple App - Base Uncontainerized App

**Input**: Design documents from `/specs/001-baseline-uncontainerized-parity/`  
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

## Phase 1: Setup (Shared Infrastructure)

- [x] T001 Create root `.specify/` scaffold from official GitHub Spec Kit initializer.
- [x] T002 Install root `.agents/skills/speckit-*` skill set for Codex workflow.
- [x] T003 Replace constitution placeholders with TraderX-specific governance in `.specify/memory/constitution.md`.
- [x] T004 Create canonical root feature pack `specs/001-baseline-uncontainerized-parity/`.
- [x] T005 Copy baseline OpenAPI contracts into `specs/001-baseline-uncontainerized-parity/contracts/**`.

## Phase 2: Foundational (Blocking)

- [x] T006 Map existing TraderSpec system requirements and user stories into root feature spec sections.
- [x] T007 Add root-level quickstart that runs full generated baseline stack and smoke checks.
- [x] T008 Define migration policy for root `specs/` vs `TraderSpec/speckit/` ownership and deprecation.
- [ ] T009 Add CI checks for `.specify` + root `specs/` artifact integrity.
- [x] T009a Produce baseline technical fidelity profile (`fidelity-profile.md`) from manifests and component catalog.
- [x] T009b Add explicit NFR constraints for stack/ports/env/contracts/code-closeness gates into root spec.
- [x] T009c Migrate legacy `TraderSpec/speckit/system/**` and `components/**` artifacts into root `specs/001.../system|components`.
- [x] T009d Rewire Spec Kit pipeline scripts to use root `specs/001...` artifacts as primary inputs.

## Phase 3: User Story 1 - Deterministic Developer Startup (P1)

- [ ] T010 [US1] Validate deterministic startup order and readiness evidence against `FR-001` and `SC-001`.
- [ ] T011 [US1] Add explicit mapping between startup/status scripts and acceptance scenarios.

## Phase 4: User Story 2 - Account + Blotter Bootstrap (P1)

- [ ] T012 [US2] Verify account list and blotter bootstrap compatibility with contracts in `contracts/account-service` and `contracts/position-service`.
- [ ] T013 [US2] Capture baseline CORS requirement evidence for UI cross-origin requests.

## Phase 5: User Story 3 - Trade Submission and Processing (P1)

- [ ] T014 [US3] Validate trade submission and downstream processing flow against `FR-007` and `FR-008`.
- [ ] T015 [US3] Verify unknown ticker/account negative-path behavior and map to acceptance scenarios.

## Phase 6: User Story 4 - Account Administration (P2)

- [ ] T016 [US4] Validate account create/update flow behavior and mapped checks.
- [ ] T017 [US4] Validate people-service user lookup and unknown-user rejection behavior.

## Phase 7: Polish & Cross-Cutting

- [x] T018 Update root `README.md` with canonical Spec Kit workflow references.
- [x] T019 Consolidate migration status into active Spec Kit docs and retire standalone migration pages.
- [ ] T020 Document branch naming strategy for Spec Kit scripts in non-`NNN-*` branches (`SPECIFY_FEATURE` fallback).
- [ ] T021 Define retirement checklist for duplicate legacy spec docs once root feature packs are complete.
- [x] T022 Add semantic compare gate execution to root quickstart and migration evidence flow.
- [x] T023 Define acceptance threshold policy for differences (allowed: docs/spec metadata only; blocked: source/runtime/contracts).
