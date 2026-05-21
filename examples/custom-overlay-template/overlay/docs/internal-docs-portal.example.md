# Internal Docs Portal Conventions

This overlay uses a separate internal docs portal that builds on TraderX public docs, but only surfaces sanctioned internal states and branches.

## Required Internal Portal Behaviors

- show a persistent red warning banner:
  - `INTERNAL DISTRIBUTION ONLY - CUSTOM OVERLAY`
- publish only sanctioned states from `overlay/catalog/sanctioned-learning-graph.example.yaml`
- include links to both:
  - upstream source state docs
  - internal generated branch docs
- clearly separate `mirrored-upstream` vs `internal-only` states

## Example Docusaurus Banner Snippet

```js
// docusaurus.config.js
themeConfig: {
  announcementBar: {
    id: "internal-distribution-warning",
    content: "INTERNAL DISTRIBUTION ONLY - CUSTOM OVERLAY",
    backgroundColor: "#b00020",
    textColor: "#ffffff",
    isCloseable: false
  }
}
```

## Suggested Navigation Sections

- Overlay Overview
- Sanctioned Learning Graph
- Runtime Policies
- Managed Service Constraints
- Internal-only State Runbooks
