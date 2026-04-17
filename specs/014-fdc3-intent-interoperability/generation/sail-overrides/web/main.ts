import express from "express"
import ViteExpress from "vite-express"
import { SailFDC3ServerFactory } from "./da/SailFDC3ServerFactory"
import { initSailSocketIOService } from "./da/initSailSocketIOService"
import { RemoteSocketService } from "./da/RemoteSocketService"
import dotenv from "dotenv"
import { getSailUrl } from "./da/sail-handlers"
import { createLogger } from "./logger"
import fs from "node:fs"
import path from "node:path"

dotenv.config()

const log = createLogger("main")
const app = express()
app.use(express.json())
const defaultClientStateCandidates = [
  process.env.SAIL_DEFAULT_CLIENT_STATE_FILE,
  path.resolve(process.cwd(), "default-client-state.json"),
  path.resolve(process.cwd(), "packages/web/default-client-state.json"),
].filter((value): value is string => Boolean(value))

const httpServer = ViteExpress.listen(app, 8090, () => {
  log.info(
    { mode: process.env.NODE_ENV, url: getSailUrl() },
    "SAIL Server started",
  )
})

const factory = new SailFDC3ServerFactory(true)
const remoteSocketService = new RemoteSocketService(httpServer, factory)
initSailSocketIOService(httpServer, factory, remoteSocketService)

app.get("/polygon-key", (_req, res) => {
  res.json({ key: process.env.POLYGON_API_KEY ?? "no-key" })
})

app.get("/demo/default-client-state", (_req, res) => {
  try {
    const defaultClientStatePath = defaultClientStateCandidates.find((candidate) =>
      fs.existsSync(candidate),
    )
    if (!defaultClientStatePath) {
      return res.status(204).end()
    }
    const raw = fs.readFileSync(defaultClientStatePath, "utf8").trim()
    if (!raw) {
      return res.status(204).end()
    }
    // Guard against malformed snapshots so bootstrap does not crash clients.
    JSON.parse(raw)
    return res.type("application/json").send(raw)
  } catch (error) {
    log.warn({ error }, "Unable to load demo default client state")
    return res.status(204).end()
  }
})

// Keep root navigation stable for local demos and health probes.
app.get("/", (_req, res) => {
  res.redirect("/html/")
})
