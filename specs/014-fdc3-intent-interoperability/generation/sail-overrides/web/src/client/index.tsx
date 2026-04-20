import { Frame } from "./frame/frame"
import { createRoot } from "react-dom/client"
import {
  getClientState,
  getAppState,
  getServerState,
} from "@finos/fdc3-sail-common"

import defaultClientState from "../../default-client-state.json"

const STORAGE_KEY = "sail-client-state"

const seedDefaultClientStateIfMissing = () => {
  try {
    const existing = localStorage.getItem(STORAGE_KEY)
    if (existing) {
      return
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(defaultClientState))
    console.info("[fdc3] seeded sail-client-state from default-client-state.json")
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
