# Security Lab learning objectives

This experimental C3 profile teaches how to establish and evaluate security boundaries while legitimate trading continues. Completion requires evidence and explanation, not simply installing tools. The profile is not yet an accepted hardened release; tasks.md records implementation status.

| Objective | Exercise and assessment |
| --- | --- |
| SL-LO-01: Establish reproducibility and trust boundaries | Identify snapshot/source/image pins; trace a normal trade across gateway, service, broker and database. Separate observed dependencies from assumed ones. |
| SL-LO-02: Attribute protection to its enforcing layer | Predict and run WAF, workload/admission, network, application authorization, SQL and NATS checks. Pair each denial with a permitted action and identify evidence proving the layer intervened. |
| SL-LO-03: Explain least privilege and residual authority | Inspect service grants and broker permissions; contrast denied unrelated operations with possible misuse inside legitimate permissions. Explain why a valid database connection is insufficient business authorization. |
| SL-LO-04: Distinguish detection, containment and prevention | Use the assumed-compromise canary, settled asynchronous outcomes and independent evidence. An alert or process termination alone earns no prevention claim. |
| SL-LO-05: Operate and recover the controls | Rotate a runtime credential, distinguish existing sessions from fresh logins, restore synthetic data and verify trading and retained evidence. |
| SL-LO-06: Evaluate remediation | Complete the optional CVE/OSERA exercise in contracts/cve-patch-analysis.md. Explain vulnerable versus fixed code, verify impact and positive behavior, and identify analysis limitations. |
| SL-LO-07: Assess coverage honestly | Map verified outcomes to versioned CCC assessment requirements; label missing evidence, local approximations, performance costs and unresolved risk. |

For every exercise, learners predict the outcome, execute the bounded scenario, inspect downloaded evidence, explain the observed effect and propose one counterexample outside the demonstrated coverage. Assessment requires the correct attribution, a passing positive control, reproducible pins, a successful reset where applicable and an explicit limitation. Failed or inconclusive runs remain visible; learners must not convert them into prevention claims.

Prerequisites: C3 trading flow, basic Kubernetes workloads/networking, SQL privileges and publish/subscribe concepts. The local console provides a subset of exercises today; unfinished objectives stay planned until their task acceptance evidence exists. An independent contributor must reproduce the completed walkthrough before release.

## Separate follow-on state: CALM-driven security

After this security profile is complete, create a separate child state with a number assigned through the repository's state process. Preserve this implementation as the comparison baseline. First bolt CALM onto the verified architecture; then demonstrate a model-first route to equivalent controls. Keep the same security objectives, positive/negative tests and expected outcomes.

Model services, trust boundaries, permitted flows, identities and control/evidence references. Evaluate existing CALM tooling and standard enforcement integrations before writing adapters. Candidate outputs include network allowlists, gateway routes, workload/admission templates, broker ACLs and SQL grant specifications. Model representation does not itself enforce these controls or infer trustworthy user identity or business authorization.

Acceptance requires pinned schemas/tooling, deterministic and idempotent generation, explicit unsupported controls, live conformance checks, and a deliberate architecture change producing only the intended policy changes. Compare maintained configuration, manual steps, change effort and drift detection with the manually built lab. Claim reduced work only where measured. Dependency patches remain explicit software changes; CALM can describe their requirements and evidence without replacing patch correctness testing.

## Identity lifecycle assessment (SL-LO-02 and SL-LO-05)

Use the local account/provider campaign in `contracts/account-enforcement.md`:

1. Predict what a reader, trader and operator can retrieve or mutate, then compare
   actual API results and independent database fingerprints.
2. Stop the provider after login. Explain why the existing access token still works
   within the API's offline trust window, and why provider outage is not revocation.
3. Replace the signing-key snapshot and account process. Prove that the old token
   was still valid under the old public key when the API rejected it, then verify
   that a newly issued token works with its existing account scope.
4. Identify the remaining gaps: automated key lifecycle, explicit logout/revocation,
   browser sessions, user-context propagation and integrated trading acceptance.

This checkpoint uses real provider-issued tokens and the real Spring API, but its
provider is disposable and its key replacement is explicit. It does not establish
that the deployed C3 environment enforces the same identity boundary.

## Browser session assessment (SL-LO-02 and SL-LO-05)

Predict the difference between a browser session cookie, an API access token and
provider SSO. Exercise the callback/state and CSRF checks in the account-only
session campaign. After local logout, show that the old session cookie fails;
explain why this does not prove revocation of every bearer token or provider SSO.
Identify the API as the account-authorization boundary, even when the browser has
successfully authenticated. Explain which behavior still needs a real Chrome and
integrated Angular trading assessment.
