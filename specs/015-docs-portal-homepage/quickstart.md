# Quickstart: Docs Portal Homepage

## Run Locally

```bash
cd website
npm run start -- --host 127.0.0.1 --port 3001
```

Open:

```text
http://127.0.0.1:3001/
```

## Verify Homepage Sources

Confirm generated states:

```bash
jq '.states | length' catalog/state-catalog.json
```

Confirm live demos:

```bash
jq '.environments | length' catalog/live-environments.json
```

The rendered homepage should show the same counts for generated state cards and live demo cards.

## Build

```bash
cd website
npm run build
```

## Regression Checklist

- `/` renders the TraderX portal homepage.
- The Knowledge Graph link opens `/docs/learning-paths`.
- State icon actions expose spec, architecture, runtime, learning, code, and ADR links where available.
- Live demo links match `catalog/live-environments.json`.
- Footer source text names `catalog/state-catalog.json` for state data.
