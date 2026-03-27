# TraderX — Learning Graph + Multi‑State Refactor
## Agentic Working Prompt (Offline, single‑file)

> **How to use this file**
> 1) Paste the entire content of this email body into your agentic LLM/chat.  
> 2) Where you see `{{PLACEHOLDER}}`, fill in the value or ask the LLM to infer from context.  
> 3) Run tasks section‑by‑section; the output should be a ready‑to‑PR bundle.

---

## 0) Context (for the LLM)
- **Project:** FINOS TraderX (sample trading app; polyglot microservices; docs site via Docusaurus).  
  - Repo: `https://github.com/finos/traderx`  
  - Demo: `https://demo.traderx.finos.org/`
- **Goal:** Redesign the repo to be *learning‑path first* and *agent‑friendly*, organizing multiple **implementation states** (“levels”) and shipping a **prompt pack** that can regenerate, explain, validate, and compare states.
- **Key Collaborations:** Solo.io will contribute a **service‑mesh proof‑point** (Istio/Envoy/Gloo). That contribution should land as the canonical Level‑3 learning path and state.
- **Design Principles:**
  1) **Keep it simple & opinionated** (avoid “kitchen sink”).  
  2) **Bind pedagogy to code:** every guide links to a runnable state.  
  3) **Make it agent‑ready:** consistent front‑matter, schemas, and prompts.  
  4) **Allow multiple entry points** (beginner → mesh → spec‑driven → AI‑first).

---

## 1) Inputs & Assumptions
- **Primary repo:** `https://github.com/finos/traderx` (default branch: `main`)
- **Learning‑path work to ingest:** `feature/learning-path` branch (focus on `docs/guide/`).  
  If unavailable, ask for an alternate branch or accept an offline folder drop.
- **Target showcase:** Refresh for **FINOS London (June {{YYYY}})**.

---

## 2) High‑Level Objectives (what you will deliver)
1) **Learning Graph v1**: a navigable set of guides with prerequisites & outcomes.  
2) **Multi‑State Repo Structure**: `/states/00..05` with runnable examples.  
3) **Prompt Pack v1**: navigation, regeneration, diff/drift, validation, and contribution.  
4) **Solo Mesh Landing Zone**: a clear Level‑3 exemplar with validation prompts.  
5) **PR Plan**: file tree, commit messages, and CI checks (front‑matter + docs build).

---

## 3) Target Repo Structure (to create/update)

```text
/states
  00-monolith/
  01-basic-microservices/
  02-containerized/
  03-service-mesh/
    solo-demo/                 # Solo’s contribution lives here
  04-contract-driven/
  05-ai-first/

/docs
  /guide/                      # learning guides (normalized front‑matter)
  /learning-paths/index.md     # Learning Graph landing page

/specs
  /contracts/                  # domain/API contracts; source of truth
  /architecture/               # CALM/C4/specs describing system

/prompts
  /navigation/
  /generation/
  /explanation/
  /validation/
  /contrib/

AGENTS.md                      # How agents consume guides/specs/states
````

> **Note:** Keep existing Docusaurus config & site build behavior intact.

***

## 4) Learning Levels ↔ States Mapping

*   **Level 0 – Local Monolith →** `/states/00-monolith`  
    *Objective:* Domain understanding; no infra dependencies.
*   **Level 1 – Basic Microservices →** `/states/01-basic-microservices`  
    *Objective:* Split services; REST; minimal config.
*   **Level 2 – Containerized →** `/states/02-containerized`  
    *Objective:* Dockerfiles; Compose; build flows.
*   **Level 3 – Service Mesh →** `/states/03-service-mesh`  
    *Objective:* Identity, policy, traffic mgmt, observability.  
    *Note:* Solo’s *solo-demo* lives here.
*   **Level 4 – Contract/Spec‑Driven →** `/states/04-contract-driven`  
    *Objective:* Markdown/API contracts → generated implementations + tests.
*   **Level 5 – AI‑First Prompt‑Driven →** `/states/05-ai-first`  
    *Objective:* Agents regenerate/validate variants; drift detection; CALM.

***

## 5) Normalized Front‑Matter (for every guide in `docs/guide`)

Use this **YAML front‑matter** block at the top of each Markdown guide:

```yaml
---
id: learn-<slug>                 # stable anchor for links & ToC
title: "<Human‑friendly title>"
level: 0|1|2|3|4|5               # maps to repo state levels
prereqs:
  - learn-<slug-a>
  - learn-<slug-b>
outcomes:
  - "You can run X locally"
  - "You can deploy Y on Z"
state:
  id: "03-service-mesh"          # exact folder under /states
  diffFromPrev: true             # render diff panel (see §7)
tags: ["service-mesh","contracts","ai-agent","observability"]
estimatedTimeMins: 20
owner: "@finos/traderx-maintainers"
---
```

**JSON Schema** (for CI validation):

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "TraderXGuideFrontMatter",
  "type": "object",
  "required": ["id", "title", "level", "state", "outcomes"],
  "properties": {
    "id": { "type": "string", "pattern": "^learn-[a-z0-9-]+$" },
    "title": { "type": "string", "minLength": 3 },
    "level": { "type": "integer", "minimum": 0, "maximum": 5 },
    "prereqs": { "type": "array", "items": { "type": "string" } },
    "outcomes": { "type": "array", "items": { "type": "string" }, "minItems": 1 },
    "state": {
      "type": "object",
      "required": ["id"],
      "properties": {
        "id": {
          "type": "string",
          "enum": [
            "00-monolith","01-basic-microservices","02-containerized",
            "03-service-mesh","04-contract-driven","05-ai-first"
          ]
        },
        "diffFromPrev": { "type": "boolean" }
      }
    },
    "tags": { "type": "array", "items": { "type": "string" } },
    "estimatedTimeMins": { "type": "integer", "minimum": 1 },
    "owner": { "type": "string" }
  },
  "additionalProperties": true
}
```

***

## 6) Docs Site Conventions

*   Each topic folder in `docs/guide` should include a `_category_.json` like:

```json
{
  "label": "Level 3 – Service Mesh",
  "position": 3,
  "link": { "type": "generated-index", "title": "Level 3 – Service Mesh Guides" }
}
```

*   Create `docs/learning-paths/index.md` as the Learning Graph landing page that:
    *   Groups guides by `level`.
    *   Shows prerequisites and estimated time.
    *   Deep‑links into `/states/<id>/` READMEs and code.

***

## 7) Diff/Drift Panels (MDX shortcode)

Embed a simple **diff panel** for guides with `diffFromPrev: true`. If you use MDX, a minimal component stub could look like:

```mdx
import DiffPanel from '@site/src/components/DiffPanel';

<DiffPanel
  fromState="02-containerized"
  toState="03-service-mesh"
  sections={[
    { title: "Infra", files: ["k8s/deploy/*", "mesh/traffic/*.yaml"] },
    { title: "Code", files: ["trade-service/src/**"] },
    { title: "Observability", files: ["mesh/telemetry/*"] }
  ]}
/>
```

If no custom component is available yet, render a **markdown table of curated diffs** (paths + rationale).

***

## 8) Solo Service‑Mesh Landing Zone (Level 3)

**Location**: `/states/03-service-mesh/solo-demo/`

**Expected contents**

*   `README.md` (what, why, how; learning objectives; teardown)
*   `manifests/` (Istio/Gloo/Envoy, policies, traffic shifting examples)
*   `scripts/` (setup, smoke tests, teardown)
*   `observability/` (golden signals dashboards, config templates)
*   `VALIDATION.md` (what “correct” looks like; links to prompts below)

**Validation Prompt** to include in `/prompts/validation/mesh-sanity-check.md`:

```markdown
System: You are a mesh reviewer for TraderX Level 3.
User: Given this running cluster and manifests, verify:
1) mTLS is enforced between services A/B/C.
2) Ingress/egress policies restrict traffic as described in README.
3) Canary rule routes 10% traffic to v2 of trade-service.
4) Golden metrics (p50/p95 latency, error rate, throughput) are visible.
Return PASS/FAIL per check, evidence (kubectl/istioctl output), and exact remediation steps.
```

***

## 9) Prompt Pack (place under `/prompts`)

### A) Navigation — `navigation/learning-path-navigator.md`

```markdown
System: You index and navigate TraderX learning paths.
User: Produce a learning itinerary filtered by:
- level(s): {{0..5 or list}}
- tags: {{list}}
For each guide: show title, id, prereqs, outcomes, estimatedTimeMins, and link to /states/<id>. Then propose the fastest route from current skills {{free-text}} to target outcomes {{free-text}}.
```

### B) Regeneration — `generation/state-from-contract.md`

```markdown
System: You generate code from contracts with tests.
User: Using files under /specs/contracts, create or update implementation in /states/04-contract-driven that compiles and passes tests.
Requirements:
- Generate service stubs, DTOs, validation, and contract tests.
- Preserve existing package names; do not break Level 2/3 builds.
- Emit a CHANGELOG section listing new artifacts and affected endpoints.
Output: file list, unified diffs, and 'how to run' steps.
```

### C) Diff/Drift — `explanation/diff-between-states.md`

```markdown
System: You explain changes across states.
User: Compare from {{fromState}} to {{toState}} across:
- Code: services, APIs, DTOs
- Infra: containers, manifests, mesh policies, gateways
- Ops: telemetry, SLOs, dashboards, runbooks
Return a narrative summary, a curated diff table (path → change → rationale), and risk/rollback notes.
```

### D) Mesh Validation — `validation/mesh-sanity-check.md`

(Provided in §8; reuse here or link.)

### E) Contribution Gateway — `contrib/new-learning-path.md`

```markdown
System: You scaffold new learning paths and states.
User: Create a new guide for level {{0..5}} with slug {{slug}} and tags {{tags}}.
Tasks:
1) Generate docs/guide/{{level}}/{{slug}}.md with normalized front‑matter.
2) Scaffold /states/{{stateId}}/{{slug}}/ with README, scripts, and a minimal runnable sample.
3) Add a PR checklist and a test script {{bash or ps1}} to validate the guide’s steps.
4) Update docs/learning-paths/index.md and AGENTS.md cross‑links.
Return: file tree, content stubs, and commit messages.
```

***

## 10) AGENTS.md (update outline)

Add/replace `AGENTS.md` with:

```markdown
# AGENTS.md — How agents work with TraderX

## Inputs
- Guides in /docs/guide with normalized front‑matter (level, state.id, outcomes)
- States in /states/* with runnable examples
- Contracts/specs in /specs/*

## Core Flows
1) Plan learning route → `/prompts/navigation/learning-path-navigator.md`
2) Generate from contracts → `/prompts/generation/state-from-contract.md`
3) Explain diffs/drift → `/prompts/explanation/diff-between-states.md`
4) Validate mesh → `/prompts/validation/mesh-sanity-check.md`
5) Scaffold new path → `/prompts/contrib/new-learning-path.md`

## Conventions
- Every guide must link to its /states/<id> folder.
- Every state has a README with run/test/teardown.
- Validation scripts exit non‑zero on failure.
```

***

## 11) Acceptance Criteria (Definition of Done)

**Docs**

*   Every `docs/guide/*.md` has valid front‑matter (schema in §5).
*   `docs/learning-paths/index.md` lists all guides grouped by `level` with prereqs/outcomes.
*   Docusaurus build passes locally (`website/` dev script) and in CI.

**States**

*   Each `/states/<level>/` has a `README.md` with **Run**, **Test**, **Teardown**.
*   Level 3 includes `solo-demo/` with working manifests and a **validation script**.

**Prompts**

*   All five prompt files exist and reference the correct paths.
*   `AGENTS.md` explains flows and points at prompts.

**PR Hygiene**

*   PR template/checklist is included; CI validates front‑matter and docs build.

***

## 12) PR Template (create `.github/pull_request_template.md`)

```markdown
## Summary
- [ ] Learning path(s) updated/added
- [ ] State(s) updated/added
- [ ] Prompt(s) updated/added
- [ ] AGENTS.md updated

## Scope
- [ ] Only one level or well‑scoped related changes
- [ ] Front‑matter validated (schema in /docs/.schema/frontmatter.json)
- [ ] Docs site builds locally
- [ ] Validation scripts pass

## Screenshots / Evidence
Attach logs for: build, tests, validation (mesh if Level 3).

## Risks & Rollback
List any breaking changes and rollback steps.
```

***

## 13) Example Files to Generate (stubs)

**`docs/learning-paths/index.md`**

```markdown
# TraderX Learning Paths

Welcome! Choose your level and follow the guides. Each guide lists its prerequisites, outcomes, and links to a runnable state.

## Level 0 — Local Monolith
- ../guide/level-0/intro-monolith.md — Outcomes: run app locally; understand core flows.

## Level 1 — Basic Microservices
- …

## Level 3 — Service Mesh (Solo)
- ../guide/level-3/mesh-solo-foundations.md
  - Prereqs: Level 2 Compose/K8s basics
  - Outcomes: mTLS, traffic shifting, observability
  - State: `/states/03-service-mesh/solo-demo/`
```

**`states/03-service-mesh/solo-demo/README.md` (skeleton)**

````markdown
# Level 3 — Service Mesh (Solo Demo)

## Objectives
- Enforce mTLS between services
- Configure ingress/egress policies
- Canary 10% traffic to trade-service v2
- Emit golden metrics and dashboards

## Run
```bash
# pre-reqs: kubectl, istioctl or gloo, docker, make
make cluster-up
make deploy
make verify
````

## Teardown

```bash
make destroy
```

## Validation

*   See `/prompts/validation/mesh-sanity-check.md`

```

---

## 14) CI Hooks (lightweight suggestions)
- **Front‑matter validation**: parse YAML, validate against the JSON schema in §5.  
- **Docs build**: run `npm ci && npm run build` under `website/` (Docusaurus v2).  
- **State smoke tests**: each `/states/*/scripts/verify.sh` must exit 0.

---

## 15) Task List for the LLM (execute in order)

1) **Ingest & Normalize**
   - Parse `docs/guide` on branch `feature/learning-path`.  
   - For each file, add/normalize front‑matter per §5.  
   - Categorize into **levels** and map `state.id`.

2) **Scaffold/Align States**
   - Ensure each mapped `/states/<id>/` exists with `README.md` and `scripts/verify.*`.  
   - For Level‑3, generate `solo-demo/` scaffold (README, manifests, scripts, observability).

3) **Generate Learning Graph**
   - Create/refresh `docs/learning-paths/index.md`.  
   - Add `_category_.json` files for level folders.

4) **Create Prompt Pack**
   - Add the five prompt files under `/prompts` (see §9).  
   - Update `AGENTS.md` (§10).

5) **Produce PR Bundle**
   - Output a file tree, suggested commit messages, and the PR template (§12).  
   - Emit a **checklist** confirming Acceptance Criteria (§11).

---

## 16) Commit Message Suggestions (squash or multi‑commit)

1) `docs(learning-paths): normalize front‑matter; add schema & categories`
2) `feat(states): scaffold 00..05 with run/test/teardown; add Level‑3 solo-demo`
3) `feat(prompts): add navigation/generation/diff/validation/contrib; update AGENTS.md`
4) `docs: add Learning Graph landing page`
5) `ci: front‑matter validator + docs build + state smoke tests`
6) `chore: add PR template and contribution checklist`

---

## 17) Constraints & Guardrails (repeat back any uncertainty)
- Preserve **approachability**; don’t add heavy infra where not required.  
- Keep **Solo demo** isolated but first‑class (clear entry, clear exit).  
- Prefer **vanilla** libraries & minimal custom code for docs components.  
- If the `feature/learning-path` branch is unavailable, **ask for an alternate path** or accept a local directory listing pasted into chat.

---

## 18) Final Outputs (what you should return to me)
- A **patch plan**: directory tree + unified diffs/stubs for new files.  
- The **Learning Graph page** content.  
- The complete **Prompt Pack** files.  
- The updated **AGENTS.md**.  
- The **PR template** and a **checklist** mapped to §11 Acceptance Criteria.  
- Any **open questions** (e.g., missing specs, unclear guide mapping).

---

## 19) Optional: CALM / Contract‑Driven Extensions
- Add `specs/architecture/calm/*` and a prompt:  
  “Given CALM markdown and contracts, generate sequence diagrams + validation tests, then reconcile drift vs implementation.”

---

## 20) Kickoff Command (have the LLM restate plan + ask for gaps)
> **Run now:** Summarize the work you will do per §§ 1–18, list any missing inputs, and start by normalizing guides found under `feature/learning-path/docs/guide`. If that branch is unreachable, pause and ask me how to supply those files.
