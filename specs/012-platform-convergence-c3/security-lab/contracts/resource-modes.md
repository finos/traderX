# Resource-aware local operation

## Intent and limits

Develop and teach security boundaries without exhausting the contributor's machine.
Resource admission is an operational prerequisite, not a security-control result.
The current host has 24 GB physical RAM; Docker is configured for 6 GB and four
CPUs. Full C3 has been observed near 4.9 GiB of Docker's roughly 5.8 GiB usable
memory. Concurrent provider startup caused severe pressure and an unresponsive
engine; sequential provider verification passed. These observations are not universal
minimum requirements or proof of the sole cause of the engine stall.

| Mode | Intended workload | Acceptance meaning |
| --- | --- | --- |
| Development | Unit tests and selected service dependencies; full clusters stopped | Local implementation checks only |
| Isolated fixture | One bounded experiment; full clusters stopped | Only the fixture's stated boundary |
| Full acceptance | Named C3 lab and intended integrated controls; other clusters stopped | Full tests still required; a capacity check alone proves nothing |

Stopping workloads requires an explicit workflow. The preflight never stops or
starts containers, modifies allocations, deletes volumes, or chooses a different
Kubernetes context. The identity harness already has an explicit `--sequential`
workflow and restarts a previously running C3 control plane in finally. It now
requires fixture preflight after stopping C3 and before starting the provider.
After any interruption, verify readiness and normal trading before accepting recovery.

## Read-only check

```bash
python scripts/security-lab/resource_preflight.py --mode acceptance
python scripts/security-lab/resource_preflight.py --mode fixture
python scripts/security-lab/resource_preflight.py --mode development
```

Exit 0 means the observed operating prerequisites pass; exit 2 means blocked.
The report includes Docker container memory observations and reasons. It does not
collect credentials, inspect container environments, or invoke experiments. Each
external diagnostic has a 15-second deadline; unavailable/malformed observations
block admission. macOS pressure must be normal. Other hosts currently report unknown
and block until a supported pressure adapter is added.

Provisional margins are 1.5 GiB of Docker headroom for an isolated fixture and
0.75 GiB for full acceptance, computed from Docker's reported memory total minus
running container working sets. VM/kernel overhead is not fully represented;
these margins are conservative policy choices to evaluate, not measured guarantees.
Development mode requires no running control-plane containers and normal host
pressure but does not certify capacity for arbitrary builds. No increase in Docker
allocation is part of this change.

The shared experiment lock serializes cooperating console runs and the three lab
build entry points: `prepare_waf.py`, `build_nats_publisher.py`, and
`build_java_candidates.py`. Child builds validate the inherited lock descriptor and
repeat capacity preflight. Builds use a 2 GiB provisional headroom margin and require
clusters stopped. Development now also requires 1.5 GiB headroom.

Console scenarios select their required mode explicitly in the server registry:
NATS uses fixture mode, WAF uses build mode (it builds its proxy), and Kubernetes/live
C3 scenarios use acceptance mode. The UI explains whether C3 must be stopped or
running. A failed preflight records `blocked`, with the observation and reason, and
never constructs/launches the experiment command. Learners cannot override the mode,
run arbitrary commands, stop C3 remotely or bypass the shared lock.

The preflight is a snapshot, not a reservation. Other standalone scripts, raw Docker,
Gradle and arbitrary shell commands are outside enforcement. This is not universal
resource admission. The minimal account environment uses the same lock and preflight;
see [account-development.md](account-development.md). Acceptance refuses a running
account development environment. Cleanup remains possible during pressure.

## Remaining implementation

- Measure per-service steady state and startup peaks, including Java heap/native memory
  and telemetry, before tuning limits or retention. Preserve all observability needed
  for full acceptance.
- Evaluate ARM64 application images with parity tests; current AMD64 images are emulated.
- Size combined C3/issuer/runtime-agent acceptance from measurements, then decide whether
  to use a larger Docker allocation or a dedicated Linux runner. Do not interpret
  isolated sequential success as proof of combined capacity.

[Console admission evidence](../evidence/2026-11-23-resource-console.json) records a
browser-verified `blocked` result while C3 was stopped and development mode active.
No experiment subprocess exit code exists because the command was never launched.
The updated runner suite passed 73 tests; all four repository validation gates passed.
