# Fresh platform setup candidate

This increment supplies verified Cilium artifacts and a guarded fresh-cluster creation path. **Fresh Cilium/network/admission checks passed, but full unattended setup remains unaccepted: application image preload exhausted Docker disk capacity.** It must not replace or adopt the existing lab. The browser lab and Citrix were left running during artifact validation.

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

It requires the reviewed macOS ARM64 Docker Desktop environment, the exclusive operation lock and normal resource preflight. Stop the lightweight lab before a deliberate full-platform session. The default cluster name is `traderx-security-lab`. An explicit `--cluster traderx-security-lab-validation` selects the separately named validation cluster; no other names are accepted. **Any existing cluster of the selected name or its control-plane container, even stopped, causes refusal**. An existing `state019-kubernetes` setup directory also causes refusal. No automatic resume, reset, deletion or adoption is provided.

The command uses kind `--retain --wait 0s`: a node without its CNI cannot become Ready before Cilium installation, so readiness is checked after the CNI rollout. `--retain` preserves the test node if kind itself fails. It creates the pinned kind cluster with a private kubeconfig under the new runtime's `state019-kubernetes` directory. It records the kube-system namespace UID, applies the exact verified Cilium manifest, waits for agent/Envoy/operator rollout, sequentially pulls the locked application images into the node and creates private SQL identities. It never applies the application control bundle directly or starts trading itself. All subprocesses use the explicit Docker Desktop socket and private Docker client directory; the user's default kubeconfig is not changed.

Failure retains the partial cluster, kubeconfig and private provisioning journal for inspection. It does not delete data or silently retry; a failed creation must not be represented as ready. Existing clusters or journal directories must not be removed just to make this command pass.

After a successful fresh creation, separately verify positive/negative network enforcement, run the platform doctor and the cumulative candidate lifecycle, and record resulting evidence. Platform rollout alone is not enforcement proof. The live creation campaign, clean-machine reproduction and standalone generated-state packaging remain release gates.

The [24 November setup evidence](../evidence/2026-11-24-platform-setup.json) records bundle repeatability and tested failure boundaries; it explicitly records that live cluster creation was not run.

## Preserving the existing lab during validation

The supported alternate cluster uses a separate runtime directory and private kubeconfig. Setup records `cluster-selection.json` create-once. Resource checks use that explicit selection and still refuse any other running control plane. Stopped clusters are preserved, not adopted. Full build/acceptance modes refuse a concurrently running account-development lab; stop that lightweight lab before the deliberate validation session and restore it afterward. Its synthetic passwords change on restart.

The network verifier accepts the same explicit cluster selection. Alternate-cluster probes additionally require the previously recorded `--cluster-uid`; they cannot default to a user context. The runtime's selection does not replace the independent kube-system UID checks in lifecycle operations. Only one cluster runs at a time. This is isolated fresh storage and cluster identity on the same Docker Desktop engine, not an independent clean machine.

## First fresh live campaign and disk gate

The [fresh-platform evidence](../evidence/2026-11-24-fresh-platform-live.json) records a separately named cluster on the existing Docker Desktop engine. Cilium/DNS became ready and bounded allowed/denied connections plus Restricted admission passed. Application image preload failed with `no space left on device`: Docker's 59 GB filesystem was full despite normal host memory pressure. Full provisioning and trading acceptance are therefore still pending.

The campaign exposed a premature node-ready wait before CNI installation and inadequate private diagnostics. The corrected code uses kind `--retain --wait 0s`, waits for node readiness after Cilium rollout, preserves private subprocess errors, and checks a provisional **2 GiB node-disk reserve before each image pull**. This reserve does not guarantee enough space for all images, unpacking and PVCs. The platform doctor reports its disk observation separately. No image, volume or cache pruning is automatic.

Only unused application images downloaded into the disposable validation node were reclaimed. The original cluster container identity was checked unchanged and remained stopped; the validation cluster was stopped after probes. A full rerun must have adequate disk capacity and validate the corrected provisioning path. A separately selected cluster on this Mac is not independent clean-machine reproduction.
