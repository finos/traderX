# Feature Pack 018: FalkorDB Portfolio Look-Through

![linux/mac](https://badgen.net/badge/linux%2Fmac/supported/green)
![windows](https://badgen.net/badge/windows/WSL2/blue)

Parent: `017-portfolio-lookthrough`. Adds a reproducible synthetic long-only portfolio exposure demonstration.

Generate with `bash pipeline/generate-state.sh 018-falkordb-lookthrough` (Windows: WSL2 Bash; PowerShell launcher: `scripts/start-state-018-falkordb-lookthrough-generated.ps1`).
Start with `scripts/start-state-018-falkordb-lookthrough-generated.sh` and visit http://localhost:8080/exposure/.
See [Quickstart](quickstart.md), [Specification](spec.md), and [Data model](data-model.md).

The primary experiment is now **firm-wide corporate-group impact**: which portfolios are exposed, and through which funds? Use `/exposure/impact`; single-portfolio look-through remains at `/exposure/`. See [the controlled pilot results](../../docs/benchmarks/portfolio-impact.md). PR #499 remains in draft; the current path-enumerating benchmark favors PostgreSQL.

The public endpoint now aggregates/ranks inside the database and retrieves only selected explanations. The full-path strategy remains available for paired measurements; see [the aggregation follow-up](../../docs/benchmarks/portfolio-impact-aggregation.md).
