import { Frame } from "./frame/frame"
import { createRoot } from "react-dom/client"
import {
  getClientState,
  getAppState,
  getServerState,
} from "@finos/fdc3-sail-common"

const STORAGE_KEY = "sail-client-state"
const DEFAULT_STATE_ENDPOINT = "/demo/default-client-state"

function createSessionId(): string {
  const randomUuid = globalThis.crypto?.randomUUID?.()
  if (randomUuid) {
    return `user-${randomUuid}`
  }
  return `user-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`
}

async function seedClientStateFromDemoSnapshot(): Promise<void> {
  const existing = localStorage.getItem(STORAGE_KEY)
  if (existing) {
    return
  }

  try {
    const response = await fetch(DEFAULT_STATE_ENDPOINT, { cache: "no-store" })
    if (!response.ok) {
      return
    }

    const raw = (await response.text()).trim()
    if (!raw) {
      return
    }

    const parsed = JSON.parse(raw)
    if (!parsed || typeof parsed !== "object") {
      return
    }

    const seededState = {
      ...parsed,
      // Avoid cross-browser collisions when multiple users load the same snapshot.
      userSessionId: createSessionId(),
    }

    localStorage.setItem(STORAGE_KEY, JSON.stringify(seededState))
    console.info("[sail] seeded client state from /demo/default-client-state")
  } catch (error) {
    console.warn("[sail] failed to seed demo client state", error)
  }
}

async function bootstrap(): Promise<void> {
  await seedClientStateFromDemoSnapshot()

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
}

void bootstrap()
