### `/prompts/session/00_session-kickoff.md`

```markdown
# TraderX — Agentic Session Kickoff

## Purpose
Coordinate an agentic refactor of the FINOS TraderX repo into a **learning‑path first**, **multi‑state** architecture with an accompanying **prompt pack**.

## Context (provide or confirm)
- Repo: https://github.com/finos/traderx
- Learning‑path branch (if available): `feature/learning-path`
- Docs site: Docusaurus v2 under `/website` with content in `/docs`
- Target showcase: FINOS London (June {{YYYY}})
- Collaboration: Solo.io will provide a **Level 3 (Service Mesh)** exemplar

## Objectives
1. Normalize and index learning guides with consistent front‑matter.
2. Map each guide to an implementation **state** (`/states/00..05`).
3. Prepare a **Prompt Pack** (navigation, generation, diff/drift, validation, contribution).
4. Provide a landing zone for Solo’s Level‑3 demo.
5. Output a clean PR plan and validation steps.

## Constraints
- Keep the repo **simple and opinionated**; avoid a “kitchen sink”.
- Preserve existing runnable paths; don’t break earlier levels.
- Prefer vanilla libs and minimal custom docs components.

## Tasks (run in this order)
1. **Inventory & Normalize**  
   - Parse `docs/guide` (on `feature/learning-path` if present).  
   - Ensure front‑matter includes: `id`, `title`, `level (0..5)`, `state.id`, `prereqs`, `outcomes`, `estimatedTimeMins`, `tags`.
   - Report any files missing required fields and propose values.

2. **States Alignment**  
   - Ensure `/states/{00..05}/` exist with `README.md` and `scripts/verify.*`.
   - For Level‑3 create `/states/03-service-mesh/solo-demo/` (README, manifests, scripts, observability stubs).

3. **Learning Graph Page**  
   - Create/refresh `docs/learning-paths/index.md`, grouped by `level`, showing prereqs and outcomes.

4. **Prompt Pack**  
   - Place the five prompts under `/prompts` as provided.  
   - Update `AGENTS.md` to explain how agents use guides, states, and prompts.

5. **PR Plan**  
   - Return a file tree, proposed commit messages, and validation checklist.

## Required Outputs
- A **patch plan** (file list + diffs or file stubs)
- The **Learning Graph** `index.md`
- The **Prompt Pack** files added under `/prompts`
- Updated `AGENTS.md` references
- A **PR checklist** mapped to acceptance criteria

## If Inputs Are Missing
- If `feature/learning-path` is unavailable, **pause** and request either:
  - a different branch name, or
  - a pasted folder listing + inline markdown of the guides.

> Start by confirming inputs, then execute Task 1 and report findings in a concise table (guide → level → state → gaps).
```

***

### `/prompts/navigation/learning-path-navigator.md`

```markdown
# Prompt — Learning Path Navigator

## System
You index, validate, and navigate TraderX learning paths. You read front‑matter in `docs/guide/**/*.md`, and cross‑reference each guide’s `state.id` with `/states/<id>/`.

## User
Build me a **learning itinerary** filtered by:
- `level`: {{0..5 or list}}
- `tags`: {{list or empty}}
- `time available (mins)`: {{integer or range}}
- `starting skills`: {{free-text}}
- `target outcomes`: {{free-text}}

### Required Steps
1. Parse all guides; extract `id`, `title`, `level`, `prereqs`, `outcomes`, `state.id`, `estimatedTimeMins`, `tags`.
2. Validate `state.id` points to an existing `/states/<id>/` folder. Flag any mismatches.
3. Recommend the **shortest path** (topological order by prereqs) from current skills to target outcomes within time budget.
4. For each guide on the path, provide:
   - Why this guide is next (prereq justification)
   - What the learner will be able to do afterward (outcomes)
   - Direct links to the guide and its `/states/<id>/` README
5. Output a **one‑click plan**:
   - `git` commands (branch creation)
   - `docs` commands (Docusaurus local run)
   - `states` commands (how to run/verify)

### Output Format
- **Itinerary summary** (bulleted)
- **Guide table** with columns: `id | title | level | time(min) | prereqs | state | gaps`
- **Validation notes** (missing state folders, missing front‑matter, orphan prereqs)
- **Run instructions** (bash code blocks)
```

***

### `/prompts/generation/state-from-contract.md`

```markdown
# Prompt — Generate Implementation from Contracts (Level 4)

## System
You generate or update **contract‑driven** implementations under `/states/04-contract-driven` using the canonical contracts in `/specs/contracts/*`. You must keep earlier levels buildable and runnable.

## User
Using the contracts under `/specs/contracts`:
1) Generate or update services, DTOs, validation, and **contract tests** for `/states/04-contract-driven`.  
2) Produce build/run instructions and ensure `scripts/verify.*` passes.  
3) **Do not** break Levels 0–3; if conflicts arise, suggest non‑breaking package or module names.

### Requirements
- Honor existing package namespaces and repository layout.
- For Java/Spring services, include controller, service, model, and test scaffolds.
- For Node/.NET components, mirror the tech stack used in earlier levels.
- Emit **contract tests** that fail on schema drift.
- Update or add CI snippets to run contract tests for Level 4 only.
- Provide a `CHANGELOG` section listing new artifacts and modified endpoints.

### Output
- **File tree** of created/modified files
- **Unified diffs** (or content stubs for new files)
- **How to run**: build, start, and verify (bash code blocks)
- **Backwards‑compatibility notes** and migration guidance
- **Open questions** (if contract ambiguities are detected)
```

***

### `/prompts/explanation/diff-between-states.md`

```markdown
# Prompt — Explain Differences Between States (Diff/Drift)

## System
You compare two implementation states and explain **what changed and why** across code, infra, and operations. You may read file trees, selected diffs, and docs.

## User
Compare from `{{fromState}}` to `{{toState}}` (e.g., `02-containerized` → `03-service-mesh`) and deliver:

### Required Analysis
1. **Architecture:** key shifts (sync vs async, gateway/mesh, identity, policies)
2. **Code:** services created/removed/modified; API and DTO changes
3. **Infrastructure:** Docker/K8s/mesh manifests; config and secrets handling
4. **Operations:** telemetry/metrics/logging; SLOs; dashboards; runbooks
5. **Risks & Rollback:** impact, revert steps, and safe rollout sequence
6. **Tests:** which tests protect the changes; what new tests are needed

### Output Format
- **Narrative summary** (1–2 paragraphs) explaining rationale and trade‑offs
- **Curated diff table**: `path | change | rationale | risk | owner`
- **CLI snippets** to validate the new state (bash code blocks)
- **Checklist** to accept the transition (teams, docs, ops handover)

> If required assets are missing, list them explicitly with suggested owners and minimal viable stubs.
```

***

### `/prompts/validation/mesh-sanity-check.md`

```markdown
# Prompt — Mesh Sanity Check (Level 3 – Solo Demo)

## System
You validate a running **service‑mesh** deployment for TraderX Level 3, ensuring identity, policy, traffic, and observability are configured as per the guide.

## Inputs
- Cluster context: {{kube-context or instructions to obtain}}
- Namespace(s): {{namespace(s)}}
- Manifests path: `/states/03-service-mesh/solo-demo/manifests`
- Observability: `/states/03-service-mesh/solo-demo/observability`

## Checks (return PASS/FAIL with evidence and remediation)
1. **mTLS enforced** between critical services A/B/C  
   - Evidence: `istioctl authn tls-check` or equivalent; policy objects present  
2. **Ingress/Egress policies** match README requirements  
   - Evidence: Gateway/VirtualService/RouteTable resources; deny‑by‑default posture  
3. **Traffic shifting (canary 10%)** to `trade-service:v2`  
   - Evidence: route weight distribution and live traffic sample  
4. **Golden metrics visible** (latency p50/p95, error rate, RPS)  
   - Evidence: dashboard or metrics endpoint; scrape config present  
5. **Health & readiness** for all mesh‑managed workloads  
   - Evidence: `kubectl get pods`, readinessProbes green; no CrashLoopBackOff

## Output
- PASS/FAIL per check, with:
  - **Command(s) run** and key output (redact secrets)
  - **Interpretation** (what it means)
  - **Remediation** (exact manifests/commands to fix)
- A final **GO/NO‑GO** recommendation and a short **playbook** for recurring validation

## Notes
- Prefer `istioctl`/`kubectl` equivalents available in the environment.
- If cluster access is unavailable, perform a **static review** of manifests and list likely failures with fixes.
```

***

### `/prompts/contrib/new-learning-path.md`

```markdown
# Prompt — Scaffold a New Learning Path + Matching State

## System
You create a **new guide** under `docs/guide` with normalized front‑matter and scaffold a matching **state** under `/states/<id>/`. You also wire up cross‑links and verification scripts.

## User
Create a new learning path with:
- `level`: {{0|1|2|3|4|5}}
- `slug`: {{kebab-case}}
- `title`: {{string}}
- `tags`: {{comma-separated list}}
- `estimatedTimeMins`: {{integer}}
- `prereqs`: {{list of guide ids or empty}}
- `outcomes`: {{bullet list of 2–5 outcomes}}
- `state.id`: {{00-monolith|01-basic-microservices|02-containerized|03-service-mesh|04-contract-driven|05-ai-first}}

### Tasks
1. **Guide file**: `docs/guide/level-{{level}}/{{slug}}.md`
   - Insert normalized front‑matter and a concise walkthrough
   - Include links to the matching `/states/<state.id>/` README
2. **State scaffold**: `/states/{{state.id}}/{{slug}}/`
   - `README.md` (Objectives, Run, Verify, Teardown)
   - `scripts/verify.sh` (or `.ps1`) returning non‑zero on failure
   - Minimal runnable sample (code or config) if appropriate
3. **Navigation**
   - Update `docs/learning-paths/index.md` with the new guide under the correct level
   - Ensure `_category_.json` exists for the level folder
4. **Wiring**
   - Add cross‑links between the guide and state README
   - If Level 3, include references to mesh validation prompt
5. **PR Hygiene**
   - Output a **file tree**, **content stubs**, and **commit messages**
   - Provide a **checklist** mapped to acceptance criteria (docs build, verify script)

### Output
- File tree (with new/modified markers)
- Markdown content stubs for each created file
- `git` command block (branch, add, commit)
- Validation steps (docs build + `scripts/verify.*`)
```

***

## Optional: `/prompts/explanation/release-notes-and-pr-plan.md`

```markdown
# Prompt — Release Notes & PR Plan

## System
You turn a set of docs/state changes into crisp release notes and a well‑scoped PR plan.

## User
Given the list of changed files and the learning paths touched, generate:
- **Release notes** (what changed, why, who benefits)
- **PR plan** with commit messages and labels
- **Risk & rollback** notes
- **Screenshots/Evidence checklist** (what to capture before merging)
```

