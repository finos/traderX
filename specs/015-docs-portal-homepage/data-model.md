# Data Model: Docs Portal Homepage

## Source Entities

### State Catalog Entry

Source: `catalog/state-catalog.json.states[]`

Required homepage fields:

- `id`
- `title`
- `status`
- `track`
- `featurePack`
- `publish.branch`

Optional homepage fields:

- `decisionRecord`
- `deploy`
- `generation`
- `previous`

Derived homepage fields:

- `featurePackSlug`
- `specUrl`
- `architectureUrl`
- `runtimeUrl`
- `learningUrl`
- `codeUrl`
- `adrUrl`

### Live Environment Entry

Source: `catalog/live-environments.json.environments[]`

Required homepage fields:

- `id`
- `name`
- `status`
- `stateId`
- `url`

Optional homepage fields:

- `stateBranch`
- `notes`

Joined homepage fields:

- `stateTitle`
- `stateStatus`
- `stateTrack`
- `generatedBranch`

## Presentation Entities

### Phase Group

A phase group is derived from state catalog `track` values. The homepage may define track labels and descriptions, but state membership must come from the catalog.

### State Action

A state action is a compact link shown on each state card.

Fields:

- `id`
- `label`
- `href`
- `external`
- `icon`
- `tooltip`

Actions must be generated from derived state links and optional ADR metadata.

## Drift Rules

- Do not duplicate state IDs, state titles, generated branch names, or demo URLs in static homepage arrays.
- If the source catalog changes and the homepage needs new presentation fields, extend the catalog or derive the value from existing catalog fields.
- Curated marketing copy may remain in component data, but it must not be described as generated.
