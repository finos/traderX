# AGENTS.md — How Agents Work with TraderX

> **Purpose**  
> Define how agentic LLMs navigate, regenerate, validate, and explain the TraderX repository using a learning‑path–first, multi‑state architecture.

**Version:** 1.0  
**Maintainers:** @finos/traderx-maintainers  
**Primary Repo:** https://github.com/finos/traderx  
**Docs Site:** `/website` (Docusaurus v2), content in `/docs`  
**Demo:** https://demo.traderx.finos.org/

---

## 1) Concepts & Goals

- **Learning Paths:** Human‑readable guides that teach a concept and map to a runnable code **state**.
- **States (Levels):** Canonical implementations of TraderX at increasing sophistication.

**Levels → Folders**

```

/states
00-monolith/              # Level 0 — local monolith
01-basic-microservices/   # Level 1 — split services, REST
02-containerized/         # Level 2 — Docker/Compose/K8s basics
03-service-mesh/          # Level 3 — identity, policies, traffic mgmt, observability
solo-demo/              # Solo.io exemplar landing zone
04-contract-driven/       # Level 4 — contracts/specs → code + tests
05-ai-first/              # Level 5 — agent-driven regeneration & drift mgmt

````

- **Prompt Pack:** Reusable prompts that agents call to navigate paths, generate code, diff states, validate mesh, and scaffold contributions.

---

## 2) Inputs Agents Consume

1. **Guides** in `docs/guide/**/*.md` with normalized **front‑matter** (see §3).  
2. **States** in `/states/<id>/` with `README.md` and `scripts/verify.*`.  
3. **Contracts/Specs** in `/specs/contracts` and `/specs/architecture`.  
4. **Prompt Pack** in `/prompts/**` (see §6).  
5. **Learning Graph** landing page: `docs/learning-paths/index.md`.

---

## 3) Front‑Matter Contract (guides)

Every guide under `docs/guide` must start with:

```yaml
---
id: learn-<slug>
title: "<Human‑friendly title>"
level: 0|1|2|3|4|5
prereqs:
  - learn-<slug-a>
outcomes:
  - "You can run X locally"
state:
  id: "00-monolith|01-basic-microservices|02-containerized|03-service-mesh|04-contract-driven|05-ai-first"
  diffFromPrev: true
tags: ["service-mesh","contracts","ai-agent"]
estimatedTimeMins: 20
owner: "@finos/traderx-maintainers"
---
````

> **CI Validation:** A JSON Schema should live at `docs/.schema/frontmatter.json`. PRs must pass schema validation.

***

## 4) Required Files in Each State

Every `/states/<id>/` folder must include:

*   `README.md` — **Objectives**, **Run**, **Verify**, **Teardown**, **What changed vs previous level**
*   `scripts/verify.sh` (or `.ps1`) — exits non‑zero on failure
*   Minimal runnable example (code/config) sufficient to pass `verify`

**Level‑3 (Service Mesh) additional:**

    /states/03-service-mesh/solo-demo/
      README.md
      manifests/                 # Istio/Gloo/Envoy/Gateway resources
      scripts/                   # setup / verify / teardown
      observability/             # dashboards or scrape configs

***

## 5) Agent Capabilities (what agents do here)

*   **Navigate:** Build an itinerary through guides based on level, tags, time, prereqs.
*   **Regenerate:** Produce Level‑4 contract‑driven implementations; generate tests; keep earlier levels runnable.
*   **Explain:** Compare two states (code, infra, ops), summarize risk, and output validation steps.
*   **Validate:** Run mesh sanity checks (mTLS, policies, canary traffic, golden metrics).
*   **Scaffold:** Create a new learning path + matching state; wire cross‑links; add verify script.
*   **Prepare PRs:** Emit file trees, commit messages, release notes, and rollback guidance.

***

## 6) Prompt Pack (entry points)

> Agents **must** use these prompts; do not free‑form improvise beyond repo conventions.

    /prompts/session/00_session-kickoff.md            # Orchestrates end‑to‑end refactor
    /prompts/navigation/learning-path-navigator.md    # Builds itineraries and validates mapping
    /prompts/generation/state-from-contract.md        # Generates Level‑4 implementation from /specs/contracts
    /prompts/explanation/diff-between-states.md       # Explains changes between states
    /prompts/validation/mesh-sanity-check.md          # Level‑3 mesh validation (Solo demo ready)
    /prompts/contrib/new-learning-path.md             # Scaffolds a new guide + state
    /prompts/explanation/release-notes-and-pr-plan.md # Optional: PR plan + release notes

***

## 7) Standard Agent Flows

### Flow A — “Learn & Run”

1.  Invoke **Navigator** prompt → choose guides by `level/tags/time`.
2.  For each guide:
    *   Open guide `READMEs` and run state `scripts/verify.*`.
    *   Record gaps (missing front‑matter, broken links, missing state).

### Flow B — “Generate from Contracts” (Level‑4)

1.  Open `/specs/contracts/*`.
2.  Invoke **State‑From‑Contract** prompt.
3.  Create/update code under `/states/04-contract-driven`; generate **contract tests**.
4.  Ensure Levels 0–3 still build/run; if not, propose non‑breaking namespacing.

### Flow C — “Explain Differences”

1.  Invoke **Diff‑Between‑States** with `fromState` → `toState`.
2.  Return narrative + curated diff table + risk/rollback + validation commands.

### Flow D — “Validate Mesh” (Level‑3)

1.  Ensure cluster context and namespaces are known (or do static review).
2.  Invoke **Mesh‑Sanity‑Check**; return PASS/FAIL with evidence & remediation.

### Flow E — “Add New Learning Path”

1.  Invoke **New‑Learning‑Path** with `level`, `slug`, `title`, `tags`, `outcomes`.
2.  Create guide + state scaffold; add verify script.
3.  Update `docs/learning-paths/index.md` and cross‑links.

### Flow F — “Prepare the PR”

1.  Summarize changes; call **Release‑Notes & PR Plan**.
2.  Include screenshots/logs for docs build, verify scripts, and (if Level‑3) mesh checks.

***

## 8) Quality Gates (must pass in CI)

```bash
# 1) Front‑matter schema validation
tools/validate-frontmatter.sh docs/guide/**/*.md

# 2) Docs site build (Docusaurus)
cd website
npm ci
npm run build

# 3) State smoke tests (minimum: changed levels)
find states -maxdepth 2 -type f -name "verify.*" -print -exec {} \;

# 4) (Level-3 only) Mesh static lint or dry‑run
kubectl kustomize states/03-service-mesh/solo-demo/manifests >/dev/null
```

***

## 9) Non‑Breaking Change Rules

*   Do **not** break Levels **0–3** when adding or modifying Level‑4/5 code.
*   If a change affects shared packages:
    *   Prefer additive changes; use **new modules/namespaces**.
    *   Provide a migration note in a `CHANGELOG` section of the PR.
*   Keep the project **approachable** (minimal custom infra; prefer vanilla).

***

## 10) Security & Privacy Guardrails

*   **No secrets** in code, manifests, or docs. Use placeholders and local env files ignored by Git.
*   **Network policies** default‑deny for Level‑3; explicitly allow required paths.
*   **Observability**: avoid PII in logs/metrics; use synthetic data.
*   **External contributions**: Respect FINOS ICLA/CCLA requirements in `CONTRIBUTING.md`.

***

## 11) Contribution Checklist (for humans & agents)

*   [ ] Guide front‑matter present and valid
*   [ ] Guide links to matching `/states/<id>/` and vice versa
*   [ ] `scripts/verify.*` exists and passes locally
*   [ ] Docs site builds (no broken sidebar or dead links)
*   [ ] For Level‑3: mesh validation plan present (`/prompts/validation/mesh-sanity-check.md`)
*   [ ] For Level‑4: contract tests generated and passing
*   [ ] Learning Graph index updated (`docs/learning-paths/index.md`)
*   [ ] PR template filled (risks, rollback, evidence)

***

## 12) Local Runbook (developer quick start)

```bash
# Clone and bootstrap
git clone https://github.com/finos/traderx
cd traderx

# Run Level‑2 (example)
cd states/02-containerized
./scripts/verify.sh

# Run docs site for authoring
cd website
npm ci
npm run start   # open http://localhost:3000

# Validate all states (smoke)
cd ..
find states -maxdepth 2 -type f -name "verify.*" -exec {} \;
```

***

## 13) Solo.io Service‑Mesh Exemplar (Level‑3)

**Landing zone:** `/states/03-service-mesh/solo-demo/`  
Agents should ensure:

*   **mTLS** between key services is enforced
*   **Ingress/Egress policies** match the guide
*   **Canary traffic** (e.g., 10% to `trade-service:v2`) is live
*   **Golden metrics** (latency p50/p95, error rate, RPS) are visible

Use the **Mesh Sanity Check** prompt and include remediation steps in output.

***

## 14) FAQs (for agents)

**Q:** The `feature/learning-path` branch isn’t available.  
**A:** Pause and request either an alternate branch name or a pasted folder listing + the guides’ markdown inline. Continue only with confirmed inputs.

**Q:** A guide’s `state.id` doesn’t exist.  
**A:** Create the state scaffold minimally (README + verify script), flag the gap in the PR.

**Q:** Docs fail to build due to category/sidebars.  
**A:** Add `_category_.json` files and ensure front‑matter `id` is unique and kebab‑case.

***

## 15) Release Management

When producing a release or showcase:

*   Generate **Release Notes** using `/prompts/explanation/release-notes-and-pr-plan.md`.
*   Tag the repo with `learning-graph-vX.Y` after CI passes.
*   Update the homepage to feature **Start Here** tiles for major entry points (Beginner / Mesh / Spec‑Driven / AI‑First).

***

## 16) Ownership & Governance

*   **Learning Graph**: @finos/traderx-maintainers
*   **Level‑3 Solo Demo**: Co‑owned; Solo contributors + maintainers code‑review
*   **Schemas & CI**: maintainers keep validation strict but approachable
*   **External Contributions**: follow `CONTRIBUTING.md` and FINOS governance

***

## 17) Minimal Acceptable State (MAS) for new content

*   A guide with valid front‑matter and at least **one** concrete, testable outcome
*   A matching state with a **passing** `scripts/verify.*`
*   Docs site builds locally
*   PR contains risk/rollback notes and evidence of verification

***

## 18) Appendix — Example Verify Script (bash)

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[verify] building services..."
./gradlew :trade-service:build

echo "[verify] starting dependencies (compose)"
docker compose -f ./compose.yml up -d --wait

echo "[verify] health checks"
curl -fsS http://localhost:8080/health > /dev/null

echo "[verify] smoke trade"
curl -fsS -X POST http://localhost:8080/trades \
  -H 'Content-Type: application/json' \
  -d '{"symbol":"AAPL","qty":10,"side":"BUY"}' > /dev/null

echo "[verify] OK"
```

> Use platform‑appropriate equivalents for Windows (`.ps1`) as needed.

