import fs from 'node:fs'
import path from 'node:path'
import {fileURLToPath} from 'node:url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

const root = path.resolve(__dirname, '..', '..')
const outDir = path.join(root, 'generated', 'api-docs')
const outFile = path.join(outDir, 'index.mdx')

fs.mkdirSync(outDir, {recursive: true})

const content = `---
title: API Explorer
---

# API Explorer

This explorer is currently scoped to \`001-baseline-uncontainerized-parity\`.

Source of truth: \`specs/001-baseline-uncontainerized-parity/contracts/**/openapi.yaml\`

## Services

- [Account Service](/api/account-service/account-service-traderx-spec-first)
- [People Service](/api/people-service/traderspec-peopleservice-webapi)
- [Position Service](/api/position-service/finos-traderx-position-service-spec-first)
- [Reference Data Service](/api/reference-data/traderspec-reference-data-service)
- [Trade Processor Service](/api/trade-processor/trade-processor-traderx)
- [Trade Service](/api/trade-service/finos-traderx-trade-service)

As additional states define their own OpenAPI contracts, this landing page will add state selectors.
`

fs.writeFileSync(outFile, content, 'utf8')
console.log(`[ok] wrote ${outFile}`)
