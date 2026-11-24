# Fresh platform setup candidate

This increment supplies verified Cilium artifacts and a guarded fresh-cluster creation path. **Creation is implemented and tested offline, but not yet live-accepted on a fresh cluster.** It must not replace or adopt the existing lab. The browser lab and Citrix were left running during artifact validation.

## Pinned inputs

The canonical infrastructure lock now records:

- The kind node image digest and canonical loopback-only kind configuration.
- Cilium 1.20.5 chart URL and archive SHA-256.
- Helm v3.17.3 and Kubernetes 1.35.0 render capabilities.
- Explicit selected chart values and the exact rendered YAML hash.
- Every rendered workload container and init-container image, including agent, operator and Envoy.

The selected values follow Cilium's [kind installation guidance](https://docs.cilium.io/en/stable/installation/kind/): Kubernetes IPAM with the existing kube-proxy retained. The fresh profile explicitly disables optional Hubble. The chart's default Helm certificate generation embeds new private keys on every render; those keys must not become review artifacts. Disabling Hubble makes this selected bundle deterministic and secret-free. Existing-cluster historical values remain separately recorded and unchanged. Enabling Hubble later requires its own private certificate lifecycle and validation.

Hashes establish the selected artifact bytes and image references; they are not signatures, vulnerability assessment or registry availability proof. Helm's executable version is checked, but this does not attest the executable binary. Kind/kubectl tool distribution and full supply-chain admission remain separate gates.

## Prepare and verify without a cluster

Install the reviewed Helm version separately. Download the chart from the lock's official URL, then pass explicit paths:

```bash
curl --fail --location https://helm.cilium.io/cilium-1.20.5.tgz --output "$HOME/cilium-1.20.5.tgz"
python scripts/security-lab/platform_setup.py prepare \
  --chart "$HOME/cilium-1.20.5.tgz" --helm /path/to/helm \
  --output "$HOME/traderx-platform-review"
python scripts/security-lab/platform_setup.py verify \
  --bundle "$HOME/traderx-platform-review" --helm /path/to/helm
python scripts/security-lab/platform_setup.py plan
```

Use the checkpoint Python environment. Prepare rejects a changed chart before executing Helm, rejects another Helm version, and checks the exact render plus container inventory. Any Secret object is refused. Output must be new; render failure leaves no partially accepted bundle. Verify rejects missing/extra/symlinked or changed files. It contacts no cluster or registry. Two independently prepared bundles must compare byte-for-byte.

## Guarded creation — live acceptance pending

Creation is a separate explicit action, not a side effect of prepare, verify or plan:

```bash
python scripts/security-lab/platform_setup.py create \
  --checkpoint /path/to/verified-state-checkpoint \
  --bundle "$HOME/traderx-platform-review" --helm /path/to/helm \
  --runtime-dir /path/to/new-private-runtime
```

It requires the reviewed macOS ARM64 Docker Desktop environment, the exclusive operation lock and normal resource preflight. Stop the lightweight lab before a deliberate full-platform session. The exact cluster name is `traderx-security-lab`; **any existing cluster of that name or its control-plane container, even stopped, causes refusal**. An existing `state019-kubernetes` setup directory also causes refusal. No automatic resume, reset, deletion or adoption is provided.

The command creates the pinned kind cluster with a private kubeconfig under the new runtime's `state019-kubernetes` directory. It records the kube-system namespace UID, applies the exact verified Cilium manifest, waits for agent/Envoy/operator rollout, sequentially pulls the locked application images into the node and creates private SQL identities. It never applies the application control bundle directly or starts trading itself. All subprocesses use the explicit Docker Desktop socket and private Docker client directory; the user's default kubeconfig is not changed.

Failure retains the partial cluster, kubeconfig and private provisioning journal for inspection. It does not delete data or silently retry; a failed creation must not be represented as ready. Existing clusters or journal directories must not be removed just to make this command pass.

After a successful fresh creation, separately verify positive/negative network enforcement, run the platform doctor and the cumulative candidate lifecycle, and record resulting evidence. Platform rollout alone is not enforcement proof. The live creation campaign, clean-machine reproduction and standalone generated-state packaging remain release gates.

The [24 November setup evidence](../evidence/2026-11-24-platform-setup.json) records bundle repeatability and tested failure boundaries; it explicitly records that live cluster creation was not run.
