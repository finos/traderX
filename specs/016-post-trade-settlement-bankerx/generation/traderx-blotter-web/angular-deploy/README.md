# Angular deploy-only assets — source of record

These files deploy to `/var/www/traderx/angular/` (nginx, local hosting —
NOT Vercel) and are loaded by the Angular app. They are deploy-only glue:
not part of the Angular build; the canonical app bundle (`main-*.js`) is
built from `templates/web-front-end/angular/` — see `PATCH-NOTE.md` for the
2026-09-30 rebuild recipe that made the bundle fully source-derived.

| file | served as | 2026-09-30 md5 |
|------|-----------|----------------|
| `bankerx-bridge.js` | `bankerx-bridge.js?v=13` | 35eb71880e4ff6186f2fc619f51764c2 |
| `../fdc3-agent-v12.js` (agent) | `fdc3-agent.js?v=14` | ff564e040d4870b074e24512e85e9435 |
| `conf.angular.html` | `conf.html` | 1a4394c4f4fdff402d4c852968b5bf2b |
| (app bundle, source-built) | `main-ZMJ5JEK4.js` | eca76fccac04c67f69aff428179aa73a |
| (app index, source-built + glue tags) | `index.html` | 1217953080e50579c3c50fd1f851f61f |

Deploying: copy to /var/www/traderx/angular/, bump the `?v=` query in the
deployed `index.html`, then verify served md5 == disk md5 (Cloudflare
caches JS assets — a plain URL may serve a stale copy).
