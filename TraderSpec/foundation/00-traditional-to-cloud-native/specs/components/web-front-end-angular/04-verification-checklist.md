# Web-Front-End (Angular) Verification Checklist

## Startup Verification

- [ ] Generated component exists in `codebase/generated-components/web-front-end-angular-specfirst`.
- [ ] `npm install` completes.
- [ ] UI starts and listens on port `18093`.

## Functional Verification

- [ ] Trade page loads and account/symbol data populate.
- [ ] Trade ticket submission to `trade-service` returns expected success/failure behavior.
- [ ] Trade blotter updates from position-service and live trade-feed events.
- [ ] Position blotter updates from position-service and live trade-feed events.
- [ ] Unknown/invalid trade submissions show expected error behavior.

## Compatibility Verification

- [ ] End-to-end GUI trade flow remains operational against generated service stack.
- [ ] Route behavior and component interactions remain parity-compatible for baseline workflows.
- [ ] No regressions in account switching and per-account feed subscription behavior.

## Suggested Commands

```bash
./TraderSpec/codebase/scripts/start-base-uncontainerized-hydrated.sh --overlay-reference-generated --overlay-database-generated --overlay-people-generated --overlay-account-generated --overlay-position-generated --overlay-trade-feed-generated --overlay-trade-processor-generated --overlay-trade-service-generated
```
