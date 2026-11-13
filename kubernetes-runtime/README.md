# State 010 Kubernetes Runtime Artifacts

Generated from:

- `specs/010-kubernetes-runtime/system/kubernetes-runtime.spec.json`
- `specs/010-kubernetes-runtime/system/nginx-edge.conf`

Artifacts:

- Kind cluster config: `kind/cluster-config.yaml`
- K8s manifests: `manifests/base`
- Image build plan: `build-plan.json`
- Observability assets: Prometheus + Grafana + Loki + Tempo + OpenTelemetry + blackbox exporter

Run:

```bash
./scripts/start-state-010-kubernetes-runtime-generated.sh
```

Primary endpoints:

- TraderX UI: `http://localhost:8080`
- API Explorer: `http://localhost:8080/api/docs`
- Grafana: `http://localhost:8080/grafana`
- Prometheus: `http://localhost:8080/prometheus`
