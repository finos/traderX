# Offline checkpoint generation contract

This is the first reproducibility increment of S019-03, not the cumulative State 019 deployment. Its baseline is the exact generated C3 commit in the prototype's `baseline.lock.json`, not whatever current C3 generates today. A changed baseline requires a reviewed source/image lock and renewed compatibility evidence.

## Inputs and outputs

Inputs: immutable generated C3 commit and recorded canonical source relationship; complete committed runtime image inventory; canonical reference and business-workload renderers. Generation requires Python with the pinned PyYAML dependency and Git, but no Docker daemon, cluster, Java build or registry access.

Outputs: `reference.json`, `business-workloads.json`, `images.lock.json` and `checkpoint.json`. The latter records source hashes, artifact hashes, baseline commits and limitations. No absolute checkout paths or current timestamps enter the output. Reference and candidate artifacts remain separate: the reference retains public demonstration credentials and anonymous messaging. Applying the business restrictions alone does not establish an integrated hardened baseline.

## Lifecycle and invariants

1. `checkpoint.py fetch-baseline` is an explicit network preparation step, fetching the immutable commit from FINOS only when absent and checking the recorded source relationship. It does not switch branches.
2. `checkpoint.py generate --output DIR` is offline. Every required image must have a consistent source/platform/digest and match the baseline pin. Missing pins fail; no registry resolution is allowed.
3. The output directory must not exist. Compilation completes before output is created, and files are private by default. Generation never resets or overwrites a learner's existing directory.
4. `checkpoint.py verify --output DIR` recompiles from the current canonical inputs and compares every byte and the complete file set. It rejects missing, extra, modified or symlinked files, including changes to the provenance manifest.
5. The repeatability check generates twice into separate directories and compares all files. This is artifact reproducibility, not image availability, clean-machine runtime reproduction or enforcement proof.

Current pins mix AMD64 application images with ARM64 infrastructure for the reviewed ARM host. Do not advertise universal host support. Signatures, complete source provenance, integrated generator/start/stop/test scripts and a fresh-machine trading campaign remain separate release gates.
