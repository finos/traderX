# Feature Pack 017: Portfolio Look-Through

![linux/mac](https://badgen.net/badge/linux%2Fmac/supported/green)
![windows](https://badgen.net/badge/windows/WSL2/blue)

Parent: `009-order-management-matcher`. Adds a reproducible synthetic long-only portfolio exposure demonstration.

Generate with `bash pipeline/generate-state.sh 017-portfolio-lookthrough` (Windows: WSL2 Bash; PowerShell launcher: `scripts/start-state-017-portfolio-lookthrough-generated.ps1`).
Start with `scripts/start-state-017-portfolio-lookthrough-generated.sh` and visit http://localhost:8080/exposure/.
See [Quickstart](quickstart.md), [Specification](spec.md), and [Data model](data-model.md).

The primary experiment is now **firm-wide corporate-group impact**: which portfolios are exposed, and through which funds? Use `/exposure/impact`; single-portfolio look-through remains at `/exposure/`. See [the controlled pilot results](../../docs/benchmarks/portfolio-impact.md). PR #499 remains in draft; the current path-enumerating benchmark favors PostgreSQL.
