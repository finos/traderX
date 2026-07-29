import { Frame } from "./frame/frame"
import { createRoot } from "react-dom/client"
import {
  getClientState,
  getAppState,
  getServerState,
} from "@finos/fdc3-sail-common"

import defaultClientState from "../../default-client-state.json"

const STORAGE_KEY = "sail-client-state"
const SEED_REVISION = "state014-refresh-2"

type SeedPanel = {
  panelId?: unknown
  [key: string]: unknown
}

type SeedState = {
  userSessionId?: unknown
  panels?: SeedPanel[]
  [key: string]: unknown
}

const cloneSeedState = (): SeedState => {
  return JSON.parse(JSON.stringify(defaultClientState)) as SeedState
}

const randomUuid = (): string => {
  if (typeof globalThis.crypto?.randomUUID === "function") {
    return globalThis.crypto.randomUUID()
  }
  return `${Date.now().toString(16)}-${Math.random().toString(16).slice(2)}`
}

const buildSeedState = (): SeedState => {
  const seeded = cloneSeedState()
  seeded.userSessionId = `user-${randomUuid()}`
  if (!Array.isArray(seeded.panels)) {
    return seeded
  }
  seeded.panels = seeded.panels.map((panel) => {
    return {
      ...panel,
      panelId: `sail-app-${randomUuid()}`,
    }
  })
  return seeded
}

const seedDefaultClientStateIfMissing = () => {
  try {
    const seededState = buildSeedState()
    localStorage.setItem(STORAGE_KEY, JSON.stringify(seededState))
    console.info(
      "[fdc3] refreshed sail-client-state from default-client-state.json",
      {
        seedRevision: SEED_REVISION,
        userSessionId: seededState.userSessionId,
      },
    )
  } catch (error) {
    console.warn("[fdc3] failed to seed sail-client-state", { error })
  }
}

seedDefaultClientStateIfMissing()

const container = document.getElementById("app")
const root = createRoot(container!)
root.render(<Frame cs={getClientState()} as={getAppState()} />)

getClientState().addStateChangeCallback(() => {
  root.render(<Frame cs={getClientState()} as={getAppState()} />)
})

getAppState().addStateChangeCallback(() => {
  root.render(<Frame cs={getClientState()} as={getAppState()} />)
})

getServerState().registerDesktopAgent(getClientState().createArgs())

getAppState().init(getServerState(), getClientState())
