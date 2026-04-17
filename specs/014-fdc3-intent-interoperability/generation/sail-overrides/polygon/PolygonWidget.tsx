import { getAgent } from "@robmoffat/fdc3"
import { memo, useEffect, useRef, useState } from "react"
import { PolygonMode } from "./common"
import { newsMode } from "./modes/news"

/* eslint-disable  @typescript-eslint/no-explicit-any */

const MODES: PolygonMode[] = [newsMode]
const INSTRUMENT_CONTEXT_TYPE = "fdc3.instrument"

function normalizeTicker(value: unknown): string | undefined {
  if (typeof value !== "string") {
    return undefined
  }
  const trimmed = value.trim().toUpperCase()
  if (!trimmed) {
    return undefined
  }
  if (trimmed.includes(":")) {
    const suffix = trimmed.split(":").pop()?.trim().toUpperCase()
    if (suffix) {
      return suffix
    }
  }
  return trimmed
}

function extractTickerFromContext(context: any): string | undefined {
  if (!context || typeof context !== "object") {
    return undefined
  }
  const ids = context.id ?? {}
  return (
    normalizeTicker(ids.ticker) ??
    normalizeTicker(ids.symbol) ??
    normalizeTicker(ids.tvSymbol) ??
    normalizeTicker(ids.ric)
  )
}

export const PolygonWidget = ({ mode }: { mode: string }) => {
  const container: any = useRef()
  const modeProps = MODES.find((m) => m.name === mode) ?? MODES[0]

  const [state, setState] = useState(modeProps.initialState)
  const [data, setData] = useState(modeProps.initialData)
  const [apiKey, setApiKey] = useState<string | null>(null)

  useEffect(() => {
    setState(modeProps.initialState)
    setData(modeProps.initialData)
  }, [mode, modeProps.initialData, modeProps.initialState])

  useEffect(() => {
    let cancelled = false

    const fetchApiKey = async () => {
      try {
        const key = await getApiKey()
        if (!cancelled) {
          setApiKey(key)
        }
      } catch (error) {
        if (!cancelled) {
          setApiKey(null)
        }
        console.warn("[fdc3] Polygon failed to load API key", { error })
      }
    }

    void fetchApiKey()
    return () => {
      cancelled = true
    }
  }, [])

  useEffect(() => {
    let cancelled = false
    let unsubscribeFns: Array<() => void> = []
    let activeAgent: any = undefined
    let registerInFlight: Promise<void> | null = null
    let lastAppliedContextSignature: string | undefined = undefined

    const clearListeners = () => {
      unsubscribeFns.forEach((unsubscribe) => unsubscribe())
      unsubscribeFns = []
      activeAgent = undefined
    }

    const resolveAgent = async (): Promise<any> => {
      const injected = (window as any)?.fdc3
      if (injected?.addContextListener || injected?.broadcast) {
        return injected
      }
      return await getAgent()
    }

    const ensureUserChannel = async (fdc3: any) => {
      if (
        typeof fdc3?.getCurrentChannel !== "function" ||
        typeof fdc3?.getUserChannels !== "function" ||
        typeof fdc3?.joinUserChannel !== "function"
      ) {
        return
      }
      try {
        const current = await Promise.resolve(fdc3.getCurrentChannel())
        if (current?.id) {
          return
        }
        const userChannels = await Promise.resolve(fdc3.getUserChannels())
        const defaultChannel = Array.isArray(userChannels)
          ? userChannels[0]
          : undefined
        if (!defaultChannel?.id) {
          return
        }
        await Promise.resolve(fdc3.joinUserChannel(defaultChannel.id))
      } catch (error) {
        console.warn("[fdc3] Polygon failed to ensure user channel", { error })
      }
    }

    const contextSignature = (context: any): string | undefined => {
      try {
        return JSON.stringify(context)
      } catch {
        return undefined
      }
    }

    const applyModeContext = (
      sourceType: "intent" | "context" | "context-wildcard" | "context-poll",
      sourceName: string,
      context: any,
      transform: (context: any, previousState: any) => any,
    ) => {
      const signature = contextSignature(context)
      if (signature && signature === lastAppliedContextSignature) {
        return
      }
      if (signature) {
        lastAppliedContextSignature = signature
      }

      setState((previousState: any) => {
        const transformed = transform(context, previousState)
        const nextTicker =
          normalizeTicker(transformed) ?? extractTickerFromContext(context)
        if (!nextTicker) {
          console.warn("[fdc3] Polygon context produced no ticker", {
            mode: modeProps.name,
            sourceType,
            sourceName,
            context,
          })
          return previousState
        }
        console.info("[fdc3] Polygon resolved ticker", {
          mode: modeProps.name,
          sourceType,
          sourceName,
          previousState,
          nextState: nextTicker,
        })
        return nextTicker
      })
    }

    const registerListeners = async (fdc3: any) => {
      const nextUnsubscribes: Array<() => void> = []

      for (const intent of modeProps.intents) {
        const listener = await Promise.resolve(
          fdc3.addIntentListener(intent.name, (context: any) => {
            applyModeContext("intent", intent.name, context, intent.function)
          }),
        )
        if (listener?.unsubscribe) {
          nextUnsubscribes.push(() => listener.unsubscribe())
        }
      }

      for (const listenerDef of modeProps.listeners) {
        const listener = await Promise.resolve(
          fdc3.addContextListener(listenerDef.name, (context: any) => {
            applyModeContext(
              "context",
              listenerDef.name,
              context,
              listenerDef.function,
            )
          }),
        )
        if (listener?.unsubscribe) {
          nextUnsubscribes.push(() => listener.unsubscribe())
        }
      }

      const wildcardListener = await Promise.resolve(
        fdc3.addContextListener((context: any) => {
          const contextType = context?.type
          if (!contextType) {
            return
          }
          const matchingListeners = modeProps.listeners.filter(
            (listenerDef) => listenerDef.name === contextType,
          )
          matchingListeners.forEach((listenerDef) =>
            applyModeContext(
              "context-wildcard",
              listenerDef.name,
              context,
              listenerDef.function,
            ),
          )
        }),
      )
      if (wildcardListener?.unsubscribe) {
        nextUnsubscribes.push(() => wildcardListener.unsubscribe())
      }

      clearListeners()
      unsubscribeFns = nextUnsubscribes
      activeAgent = fdc3
      console.info("[fdc3] Polygon listeners registered", { mode: modeProps.name })
    }

    const syncContextFromChannel = async (fdc3: any) => {
      if (typeof fdc3?.getCurrentChannel !== "function") {
        return
      }
      try {
        const currentChannel = await Promise.resolve(fdc3.getCurrentChannel())
        if (!currentChannel || typeof currentChannel.getCurrentContext !== "function") {
          return
        }
        const context = await Promise.resolve(
          currentChannel.getCurrentContext(INSTRUMENT_CONTEXT_TYPE),
        )
        if (!context) {
          return
        }
        modeProps.listeners
          .filter((listenerDef) => listenerDef.name === INSTRUMENT_CONTEXT_TYPE)
          .forEach((listenerDef) =>
            applyModeContext(
              "context-poll",
              listenerDef.name,
              context,
              listenerDef.function,
            ),
          )
      } catch (error) {
        console.warn("[fdc3] Polygon channel context sync failed", {
          mode: modeProps.name,
          error,
        })
      }
    }

    const ensureConnected = async () => {
      if (cancelled || registerInFlight) {
        return
      }
      registerInFlight = (async () => {
        try {
          const fdc3 = await resolveAgent()
          if (!fdc3) {
            throw new Error("FDC3 agent not available")
          }
          if (!(activeAgent === fdc3 && unsubscribeFns.length > 0)) {
            await ensureUserChannel(fdc3)
            await registerListeners(fdc3)
          }
          await syncContextFromChannel(fdc3)
        } catch (error) {
          if (unsubscribeFns.length > 0) {
            clearListeners()
          }
          console.warn("[fdc3] Polygon listener registration failed", {
            mode: modeProps.name,
            error,
          })
        }
      })()

      try {
        await registerInFlight
      } finally {
        registerInFlight = null
      }
    }

    const intervalId = window.setInterval(() => {
      void ensureConnected()
    }, 2000)
    void ensureConnected()

    return () => {
      cancelled = true
      window.clearInterval(intervalId)
      clearListeners()
    }
  }, [mode, modeProps])

  useEffect(() => {
    let cancelled = false
    const call = async () => {
      if (!apiKey) {
        return
      }
      const ticker = normalizeTicker(state) ?? normalizeTicker(modeProps.initialState)
      if (!ticker) {
        return
      }
      const endpoint = modeProps.endpoint(ticker, apiKey)
      try {
        const response = await fetch(endpoint)
        const payload = await response.json()
        if (!cancelled) {
          setData(() => payload)
        }
      } catch (error) {
        console.warn("[fdc3] Polygon fetch failed", { endpoint, error })
      }
    }
    void call()
    return () => {
      cancelled = true
    }
  }, [apiKey, modeProps, state])

  return (
    <div id="polygon-widget" ref={container}>
      {modeProps.stateRenderer(state)}
      {modeProps.dataRenderer(data)}
      <div className="polygon-widget-copyright">
        <a
          href="https://www.polygon.io/"
          rel="noopener nofollow"
          target="_blank"
        >
          <span className="blue-text"> Powered by Polygon </span>
        </a>
      </div>
    </div>
  )
}

export default memo(PolygonWidget)

async function getApiKey() {
  const response = await fetch("/polygon-key")
  const data = await response.json()
  return data.key
}
