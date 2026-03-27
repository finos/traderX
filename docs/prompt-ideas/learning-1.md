I’m using: TraderX repo & docs structure (incl. Docusaurus site and `AGENTS.md`) to anchor where these guides should live and how they’ll be rendered and consumed by agents. [\[github.com\]](https://github.com/finos/traderX), [\[github.com\]](https://github.com/finos/traderX/blob/main/docs/overview.md)

***

## 1) Canonicalize the learning‑path guides (front‑matter + taxonomy)

**Goal:** Make each guide machine‑navigable by an agent and human‑navigable on the website.

**Action**  
Add uniform front‑matter to every guide in `docs/guide`:

```md
---
id: learn-<slug>          # stable anchor for Docusaurus + cross-links
title: "<human-friendly title>"
level: 0|1|2|3|4|5        # maps to repo states (see §2)
prereqs:
  - learn-<slug-a>
  - learn-<slug-b>
outcomes:
  - "You can run X locally"
  - "You can deploy Y on Z"
state:
  id: "03-service-mesh"   # exact /states folder name
  diffFromPrev: true      # render a code/infra diff panel
tags: ["service-mesh","contracts","ai-agent","observability"]
estimatedTimeMins: 20
owner: "@finos/traderx-maintainers"
---
```

**Why this matters:**

*   Docusaurus consumes the front‑matter to produce clean nav/ToC on the docs site. [\[deepwiki.com\]](https://deepwiki.com/cognition-workshop/finos-traderX/7.3-documentation-website)
*   Agents (and your future `AGENTS.md` flows) can **filter by `level` and `state`** to fetch the right code, run the right scripts, and explain diffs. (Repo already includes `AGENTS.md`, which we’ll extend to reference these guides programmatically.) [\[github.com\]](https://github.com/finos/traderX)

***

## 2) Bind guides to the **Learning Graph ↔ Repo States** (one‑to‑one)

Use a **6‑level spine** and map each guide to a state. (You can rename levels; the key is stability.)

*   **Level 0 – Local Monolith → `/states/00-monolith`**  
    *Focus:* Domain understanding; zero infra.
*   **Level 1 – Basic Microservices → `/states/01-basic-microservices`**  
    *Focus:* Split services; REST; simple wiring.
*   **Level 2 – Containerized → `/states/02-containerized`**  
    *Focus:* Dockerfiles; Compose; build tooling.
*   **Level 3 – Service Mesh → `/states/03-service-mesh`**  
    *Focus:* Solo/Istio gateway, identity, policies, traffic mgmt.  
    *(Solo’s proof‑point lands here; keep the guide crisp and opinionated.)*
*   **Level 4 – Contract‑/Spec‑Driven → `/states/04-contract-driven`**  
    *Focus:* Markdown specs → generated code/tests; validation prompts.
*   **Level 5 – AI‑First Prompt‑Driven → `/states/05-ai-first`**  
    *Focus:* Agents regenerate variants; drift/diff explainers; CALM.

> TraderX already publishes a docs site; this mapping lets Docusaurus render a left‑nav by *Learning Path* and a cross‑nav by *State/Level*. [\[github.com\]](https://github.com/finos/traderX), [\[github.com\]](https://github.com/finos/traderX/blob/main/docs/overview.md)

***

## 3) Move/merge the branch content cleanly

*   **Destination:**
    *   `docs/guide/...` → keep path but **enforce front‑matter** and add `_category_.json` files so sections render in the website. [\[deepwiki.com\]](https://deepwiki.com/cognition-workshop/finos-traderX/7.3-documentation-website)
    *   Create `docs/learning-paths/index.md` as the **graph landing page** with links grouped by `level` and `tags`.
*   **Cross‑links:** Each guide’s `state.id` must point to the matching folder under `/states/<id>`.
*   **“Diff from previous state” blocks:** Add a shortcode/MDX component to show curated diffs (e.g., compose → k8s manifests, or no‑mesh → mesh).
*   **Surfacing on homepage:** Update the Docusaurus config/landing components to feature “Start Here” tiles (Beginner / Mesh / Spec‑Driven / AI‑First). [\[deepwiki.com\]](https://deepwiki.com/cognition-workshop/finos-traderX/7.3-documentation-website)

***

## 4) Encode **Solo’s service‑mesh demo** as a first‑class learning path

*   **Guide:** `docs/guide/mesh/getting-started-with-solo.md`
    *   `level: 3`, `state.id: "03-service-mesh"`
    *   Outcomes: traffic shifting, mTLS, basic policies, observability recipe.
*   **State pack:** `/states/03-service-mesh/solo-demo/`
    *   Mesh manifests (Istio/Envoy/Gloo), scripted setup, teardown, and sanity checks.
*   **Validation prompt:** Add an agent recipe: “*Given this mesh config and running cluster, verify identity, traffic policy, and golden metrics are present; produce remediation steps if not*.”
*   **Contribution spec:** A simple `CONTRIBUTING.md` in that subfolder to let Solo iterate without bloating other states.

> This makes Solo’s demo a **proof point** attached to Level 3 while preserving the “simple, opinionated, non‑kitchen‑sink” ethos. (Repo already demonstrates polyglot microservices and multiple deployment modes; we’re adding a clean mesh landing zone.) [\[github.com\]](https://github.com/finos/traderX/blob/main/README.md)

***

## 5) Wire the guides into an **Agent‑friendly Prompt Pack**

Place these under `/prompts` and cross‑reference from each guide:

**A. Navigation & Planning** (`/prompts/navigation/learning-path-navigator.md`)

*   “List all guides for `level=3` sorted by prereqs; show linked `/states` folders and estimated time.”

**B. State Regeneration** (`/prompts/generation/state-from-contract.md`)

*   “Given `specs/contracts/*.md`, generate implementation in `/states/04-contract-driven` with tests.”

**C. Diff/Drift** (`/prompts/explanation/diff-between-states.md`)

*   “Explain exactly what changed from `02-containerized` → `03-service-mesh` across code, infra, and runtime.”

**D. Mesh Validation** (`/prompts/validation/mesh-sanity-check.md`)

*   “Verify mTLS, traffic policy, and golden signals; emit actionable fixes.”

**E. Contribution Gateway** (`/prompts/contrib/new-learning-path.md`)

*   One prompt to scaffold a new guide **with front‑matter**, a matching `/states/...` skeleton, and **a PR checklist**.

> Pair this with the existing `AGENTS.md` to document how an agent should consume guides, specs, and states together. [\[github.com\]](https://github.com/finos/traderX)

***

## 6) Minimal repo changes to make this all “click”

    /states
      00-monolith/
      01-basic-microservices/
      02-containerized/
      03-service-mesh/
        solo-demo/
      04-contract-driven/
      05-ai-first/
    /docs
      /guide
        /level-0 ... /level-5  # or thematic folders; both work with _category_.json
      /learning-paths/index.md
    /specs
      /contracts
      /architecture
    /prompts
      /navigation /generation /explanation /validation /contrib
    AGENTS.md                  # extended to reference the prompt pack + guides

*   **Labels:** `level:0..5`, `state:<id>`, `topic:mesh|contracts|ai`
*   **CI checks:** validate front‑matter schema; fail PR if `state.id` doesn’t resolve.
*   **Docs site:** ensure Docusaurus builds still succeed; add a “Learning Paths” top‑nav. [\[deepwiki.com\]](https://deepwiki.com/cognition-workshop/finos-traderX/7.3-documentation-website)

***

## 7) Quick win deliverables for the next community call

1.  **Learning Graph v1**: the index page that lists all guides by level (with prereqs/outcomes).
2.  **One exemplar path fully wired**: pick **Level 3 (mesh)** and ship end‑to‑end (guide + state + prompts).
3.  **Contribution gateway**: the single prompt + checklist that scaffolds new paths cleanly.
4.  **`AGENTS.md` update**: show how agents use the graph (inputs → actions → outputs). [\[github.com\]](https://github.com/finos/traderX)

***

## Copy‑paste starter prompt for your agentic working session

> Use this at the start of your redesign session; it will **ingest the branch guides** and align them to states.

```markdown
You are helping me refactor the FINOS TraderX repo to be learning‑path and agent‑first.

**Context repos & docs**
- Primary repo: https://github.com/finos/traderx
- Learning‑path branch to ingest: feature/learning-path (focus: docs/guide)
- Docs site is Docusaurus; keep front‑matter and navigation coherent.

**Objectives**
1) Parse all guides under docs/guide on the feature/learning-path branch.
2) Add/normalize front‑matter (id, title, level 0..5, prereqs, outcomes, state.id, tags, estimatedTimeMins, owner).
3) Map each guide to one of these states:
   00-monolith, 01-basic-microservices, 02-containerized,
   03-service-mesh, 04-contract-driven, 05-ai-first.
4) For each guide, propose:
   - the matching /states/<id>/ subfolder (create if missing),
   - a short list of concrete code/infra diffs vs the previous level,
   - a test/check script name for sanity checks.
5) Generate:
   - /docs/learning-paths/index.md (the Learning Graph landing page),
   - /prompts/navigation/learning-path-navigator.md,
   - /prompts/explanation/diff-between-states.md,
   - /prompts/contrib/new-learning-path.md,
   - an update to AGENTS.md that explains how agents navigate guides and states.
6) Produce a PR plan (file list + commit messages) and call out any missing specs.

**Constraints**
- Keep the project simple and opinionated; avoid a “kitchen sink”.
- Solo’s service mesh demo is the canonical Level 3 exemplar.
- All guides must compile in the docs site build; include _category_.json where needed.

**Output**
- A markdown patch plan with directory tree, new/changed file stubs, and any schema files.
- A checklist I can paste into a GitHub issue for the community to execute.
```
 
