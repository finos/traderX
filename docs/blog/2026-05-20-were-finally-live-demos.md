---
title: "May 20, 2026: We’re Finally Live with TraderX Demos"
slug: /blog/2026-05-20-were-finally-live-demos
---

# We’re Finally Live with TraderX Demos

After a lot of design, implementation, debugging, and deployment work, TraderX now has live FINOS-hosted demo environments:

- Original Demo (state `004`): [https://demo.traderx.finos.org](https://demo.traderx.finos.org)
- Advanced Demo (state `009`): [https://demo-advanced.traderx.finos.org](https://demo-advanced.traderx.finos.org)

Huge thanks to the FINOS team and everyone who helped us get this over the line.  
Tracking issue: [#334](https://github.com/finos/traderX/issues/334)

We are now in position for final merge, with live environments proving the current generated-state path and deployment model.

## What We Did Along The Way

- Moved to a SpecKit-first, state-driven architecture.
- Standardized generated-state branch publishing and lineage.
- Thanks to this approach, we rapidly built out key states in the TraderX [visual learning graph](/docs/learning-paths).
- Added state-aware reverse-proxy snippet generation for websocket transport routes.
- Tightened CORS/domain propagation so deployed environments use correct FQDN-based origins.
- Removed dev-runtime leakage (for example Vite hot-reload endpoints) from deployed container images.
- Added canonical live environment mapping in project source-of-truth docs/catalog.

## What’s Next

- Harden deployment automation further across environments.
- Move generated-state branch publication deeper into CI-driven automation.
- Continue improving convergence-state deployment contracts, including Kubernetes-profile deployment bundles.
- Expand smoke/regression coverage so future state changes stay safe by default.

TraderX is in a strong position for the next phase: reliable generated-state delivery, better operational repeatability, and faster evolution on top of a clearer architecture model.
