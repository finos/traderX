# State 019 CCC assessment map

This is an evidence-backed candidate mapping, not a FINOS CCC certification,
managed-cloud compliance assertion, or State 019 acceptance claim. The JSON
file beside this document is canonical; it records each assessment requirement,
implementation path, test command, committed evidence path, result, scope/status,
and limitation. Paths are repository-relative so the map can be checked offline.

## Catalog sources

| Catalog | Version used | Official source |
| --- | --- | --- |
| Load balancer | `networking/loadbalancer/v2026.11` | [FINOS CCC catalog at pinned commit](https://github.com/finos/common-cloud-controls/blob/56a388a18a6f2fdf13d933a0f9eddb16c8c9ccac/catalogs/networking/loadbalancer/controls.yaml) |
| Kubernetes | `orchestration/k8s/v2026.11` | [FINOS CCC catalog at pinned commit](https://github.com/finos/common-cloud-controls/blob/f36872f7ff09bd4db6670f560707107bc3c0a548/catalogs/orchestration/k8s/controls.yaml) |
| Relational database | `database/relational/v2026.11` | [FINOS CCC catalog at pinned commit](https://github.com/finos/common-cloud-controls/blob/56a388a18a6f2fdf13d933a0f9eddb16c8c9ccac/catalogs/database/relational/controls.yaml) |

The release tags were checked independently: Kubernetes resolves to
`f36872f7ff09bd4db6670f560707107bc3c0a548`, while load-balancer and relational
resolve to `56a388a18a6f2fdf13d933a0f9eddb16c8c9ccac`. The Kubernetes release
includes `CCC.K8S.CN23.AR01`; runtime detection is not `CN14.AR05` in this
version. Requirement text was compared with each pinned official catalog.

## Control summary

| CCC control | Candidate requirement coverage | Evidence/status | Limitation |
| --- | --- | --- | --- |
| `CCC.LB.CN11` | AR01 partial; AR02 verified within fixture | Local WAF fixture | Not associated with a deployed internet-facing listener or Envoy Gateway; not managed-cloud coverage. |
| `CCC.K8S.CN06` | AR01–AR02 verified within scope | Deployed local kind/Cilium probe | One isolated namespace/flow; not complete State 019 network acceptance or a managed cluster. |
| `CCC.RDMS.CN07` | AR01–AR02 verified within scope | Deployed local PostgreSQL in isolated kind lab | Not a managed database assessment; service-grant tests do not prove business authorization or full State 019 cutover. |
| `CCC.K8S.CN23` | AR01 planned | No runtime-engine result | Released requirement; no sensor, alert, detection, or prevention result. |
| `CCC.K8S.CN05` | AR01–AR02 verified within scope | Deployed local-cluster admission/workload checks | Selected namespaces/workloads only; not universal cluster coverage or runtime prevention. |
| `CCC.K8S.CN04` | AR01 partial; AR02–AR03 planned | Component/image digest candidates | Digest pins do not prove approved-registry admission, signature/provenance verification, or vulnerability blocking. |
| `CCC.K8S.CN19` | AR01–AR04 planned | No external exposure assessment | No load-balancer, Ingress, Gateway, external-IP, source-allowlist, or NodePort policy result. |
| `CCC.K8S.CN02` | AR05 verified within scope; AR01–AR04/AR06 not assessed | Selected deployed local-cluster identities | No complete cluster-wide inventory or privileged-role review. |
| `CCC.K8S.CN07` | AR01–AR02/AR04–AR05 partial; AR03 not assessed | Selected deployed local-cluster secret/token checks | No cluster-wide secret inventory or cloud KMS evidence. |
| `CCC.K8S.CN14` | AR01–AR02 partial; AR03–AR04 not assessed | Local telemetry persistence and collector boundary | Does not establish Kubernetes audit logs, external independent custody, security-change alerts, or runtime detection. |

## Scope and interpretation

- **Local fixture:** the WAF is an isolated Envoy/Coraza fixture with a harmless
  recording backend. Its block-mode result is not deployed WAF coverage, and an
  Off-mode backend receipt is not a verified exploit.
- **Deployed local cluster:** Cilium, admission, PostgreSQL, workload, and
  telemetry observations were collected in the dedicated local kind lab. They
  are not managed-cloud configuration assessments or blanket State 019
  acceptance.
- **Component candidate:** pinned image references and State 019 HTTP
  authorization/execution candidate results do not prove a deployed trust
  policy. HTTP authorization is not NATS subject authorization; mocked TLS is
  not deployment trust.
- **Managed-cloud approximation:** none is claimed by this mapping.
- **Runtime:** detection (alerting on suspicious activity) and prevention
  (stopping the activity before impact) are separate results. No runtime engine
  is selected or evidenced as integrated; a future observation result cannot
  be labeled prevention.
- **Future comparisons:** ingress/gateway and service-mesh profiles, and the
  separate CALM comparison, remain future work as recorded in
  [the platform comparison](platform-control-comparison.md).

Run the offline path/status check from any working directory:

```sh
python3 scripts/security-lab/validate_ccc_assessment.py
python3 -m unittest discover -s scripts/security-lab -p 'test_validate_ccc_assessment.py' -v
```

The validator checks local references and vocabulary only. It does not fetch or
authenticate the official catalog, validate live infrastructure, or turn a
recorded test into a certification.
