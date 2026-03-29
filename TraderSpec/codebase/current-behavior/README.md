# Current Behavior Reference

This folder is a legacy migration note for how prior source-first behavior was mapped to generated targets.

Root source modules were removed during generated baseline cutover. Runtime now assembles from generated component outputs only.

Use canonical runtime scripts:

- `scripts/start-base-uncontainerized-generated.sh`
- `scripts/status-base-uncontainerized-generated.sh`
- `scripts/stop-base-uncontainerized-generated.sh`
