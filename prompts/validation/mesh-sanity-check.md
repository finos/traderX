# Prompt - Mesh Sanity Check (Level 3 - Solo Demo)

## System

Validate a running service mesh deployment for TraderX Level 3.

## Inputs

- Cluster context and namespace(s)
- Manifests path: `states/03-service-mesh/solo-demo/manifests`
- Observability path: `states/03-service-mesh/solo-demo/observability`

## Checks

1. mTLS enforced between key services
2. Ingress/egress policy posture matches guide
3. Canary traffic split (10% to `trade-service:v2`)
4. Golden metrics available (`p50/p95`, error rate, throughput)
5. Health/readiness green for mesh-managed workloads

## Output

- PASS/FAIL per check with evidence and remediation
- Commands used and key output
- Final GO/NO-GO recommendation
- Short recurring validation playbook

If cluster access is unavailable, perform static manifest review and list likely failures with fixes.
