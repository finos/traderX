# State 019 prototype quickstart

**The generated State 019 runtime is not available yet.** The current prototype uses a pinned C3 snapshot and local fixtures. Do not interpret these as a complete hardened trading deployment.

Follow the [learner onboarding contract](../012-platform-convergence-c3/security-lab/contracts/learner-onboarding.md) for supported host prerequisites, certificate trust and the existing lightweight account experiment:

```bash
scripts/security-lab/traderx-lab doctor
scripts/security-lab/traderx-lab setup
scripts/security-lab/traderx-lab start
scripts/security-lab/traderx-lab status
scripts/security-lab/traderx-lab stop
```

Setup may require building the pinned candidate and explicit local CA installation; it is not a universal one-command installer. Keep credentials in the private runtime location printed by the launcher. Run one cluster at a time. Use the [learning progression](../012-platform-convergence-c3/security-lab/progression.md) to distinguish verified checkpoints from planned exercises. Fresh-machine reproduction remains a release gate.
