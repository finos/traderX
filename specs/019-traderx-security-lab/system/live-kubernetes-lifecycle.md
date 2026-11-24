# Live Kubernetes lifecycle and bounded trading candidate

This increment validates the database lifecycle on a real Kubernetes cluster, followed by a bounded trading-function deployment. It does not enable the full State 019 generated runtime. The four stateful telemetry deployments and collector migration remain separate; identity, authenticated NATS, WAF/network integration and image trust are still release gates.

## Resource and ownership model

Use the existing dedicated `kind-traderx-security-lab` cluster and its private kubeconfig. Stop the lightweight account development environment before full-cluster work, and keep state-014 stopped. The adapter takes the shared operation lock, checks host pressure/Docker headroom, and requires the expected `kube-system` namespace UID. It does not create, delete or start clusters automatically.

A separate namespace such as `traderx-security-lab-019` lets the candidate coexist with preserved prototype storage. The database adapter permits only the `traderx-security-lab` namespace family; the trading candidate requires a suffix. Namespace selection never rewrites the original prototype. Ownership labels derive from the private credential store, while object UID/resource-version preconditions protect scale operations. No existing namespace is adopted automatically.

Before the recorded campaign, the older prototype's nineteen Deployment replica settings were saved privately and those Deployments were scaled to zero. Only the candidate was subsequently rolled out. This is an explicit host transition, not an automatic action of the adapters. Resource observations are snapshots, not memory reservations.

## Database acceptance

`verify_kubernetes_database.py` requires an absent namespace and a previously created private credential store. It:

1. Creates five immutable SQL Secrets, a Restricted namespace, a service account, a seed-suppressing ConfigMap and a persistent database deployment.
2. Injects a SQL transaction failure and verifies that startup scales the database back to zero.
3. Retries clean initialization, proving that the failed transaction did not leave partial schema/role state.
4. Commits a synthetic canary and records the seed fingerprints, PVC UID and Secret UIDs.
5. Stops and starts twice, observing three distinct Pod UIDs with the same PVC, Secrets, credentials and committed data.
6. Calls stop twice and retains all storage and credentials.

Choose a new namespace and evidence filename for a fresh campaign. An existing namespace is refused, never reset. The test retains its PVC and Secrets for inspection; stop does not erase evidence or data.

## Trading-function deployment

`trading_lifecycle.py` composes the eight restricted business workloads and six supporting workloads from the pinned C3 renderers, with scoped SQL Secret references. Together with the database, this is fifteen Deployments, not the full nineteen-workload observability deployment. It creates supporting Services/ConfigMaps and scopes five admission policy/binding pairs to the candidate namespace without modifying prototype policies.

Services are ClusterIP only. The verifier temporarily forwards the edge service to loopback, confirms that its own process bound the port, and closes it afterward. No NodePort or public tunnel is created. Reference broker/business authentication remains unchanged; this candidate must not be advertised as an authenticated security-lab entry point.

Startup validates existing resource fields before creating missing resources, verifies/resumes the database, and rolls out services sequentially with a resource check before each service. Failure attempts an owned shutdown and retains resources for diagnosis. Stop scales the candidate workloads down and preserves the database PVC and Secrets. It does not delete admission policies, storage, namespaces or unrelated workloads.

`verify_trading_lifecycle.py` submits a synthetic trade, waits for asynchronous settlement through the position API and independently checks the SQL row. It also checks rejected unknown accounts/tickers, creates a deliberately nonmarketable limit order, lists it by account, cancels it and checks the final database status. These are business-function and scoped-database compatibility checks, not user-authorization or broker-permission tests.

## Contributor commands

Create the private store using the [database bootstrap contract](fresh-database-bootstrap.md). For each command below, supply the explicit private runtime directory, store, kubeconfig, context and expected cluster UID:

```bash
python scripts/security-lab/verify_kubernetes_database.py --help
python scripts/security-lab/trading_lifecycle.py --help
python scripts/security-lab/verify_trading_lifecycle.py --help
```

Run the database campaign first, then `trading_lifecycle.py start`, then the trading verifier, then `trading_lifecycle.py stop`. The database verifier and trading verifier each require a new `--output` evidence filename. All use the same namespace and credential store. The adapters are contributor entrypoints; guided learner onboarding is not yet wired to this candidate.

Remaining acceptance includes fresh telemetry data directories and collector isolation, the complete cumulative start/stop/test command, a clean-machine run, staged portal integration and all security controls still marked pending in the task ledger.

The pinned trade submission API returns a null request ID; the processor assigns the committed trade UUID. The verifier therefore selects a previously absent synthetic account/security/side/quantity combination, requires exactly one settled API result and verifies its committed ID and unique SQL row. It does not claim end-to-end request-ID propagation. A server-side dry run also verifies that the candidate workload policy rejects a writable root filesystem without changing the running deployment.

The [24 November live evidence](../evidence/2026-11-24-live-kubernetes-trading.json) records both passing campaigns and a resource observation. After validation, all fifteen candidate Deployments were stopped, both Kubernetes clusters were left stopped, and the preserved lightweight account lab was restarted. Candidate PVCs, Secrets and manifests remain available for the next acceptance session.
