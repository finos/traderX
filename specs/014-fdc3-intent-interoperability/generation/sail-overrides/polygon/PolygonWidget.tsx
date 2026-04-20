import { getAgent } from "@robmoffat/fdc3"
import { memo, useEffect, useRef, useState } from "react"
import { PolygonMode } from "./common"
import { newsMode } from "./modes/news"

/* eslint-disable  @typescript-eslint/no-explicit-any */

type Fdc3ListenerHandle = { unsubscribe?: () => void }

const MODES: PolygonMode[] = [newsMode]

const isInstrumentContext = (context: any) => context?.type === "fdc3.instrument"

const normalizeTicker = (value: unknown): string | undefined => {
  if (typeof value !== "string") return undefined
  const raw = value.trim().toUpperCase()
  if (!raw) return undefined
  if (raw.includes(":")) {
    const parts = raw.split(":")
    return parts[parts.length - 1] || undefined
  }
  return raw
}

const pickFirstTicker = (values: unknown[]): string | undefined => {
  for (const value of values) {
    const ticker = normalizeTicker(value)
    if (ticker) {
      return ticker
    }
  }
  return undefined
}

const resolveTickerFromContext = (context: any): string | undefined => {
  return pickFirstTicker([
    context?.id?.ticker,
    context?.id?.symbol,
    context?.ticker,
    context?.symbol,
    context?.context?.id?.ticker,
    context?.context?.id?.symbol,
    context?.context?.ticker,
    context?.context?.symbol,
    context?.data?.id?.ticker,
    context?.data?.id?.symbol,
    context?.result?.id?.ticker,
    context?.result?.id?.symbol,
    context?.result?.context?.id?.ticker,
    context?.result?.context?.id?.symbol,
  ])
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
  }, [modeProps])

  useEffect(() => {
    let disposed = false

    async function fetchApiKey() {
      try {
        const key = await getApiKey()
        if (!disposed) {
          setApiKey(key)
        }
      } catch (error) {
        console.warn("[fdc3] Polygon failed to load API key", { error })
      }
    }

    fetchApiKey()

    return () => {
      disposed = true
    }
  }, [])

  useEffect(() => {
    let disposed = false
    let intervalId: number | undefined
    let channelChangedHandler: (() => void) | undefined
    const handles: Fdc3ListenerHandle[] = []

    const applyContext = (context: any, source: "listener" | "channel-sync") => {
      if (!context) return
      modeProps.listeners.forEach((listener) => {
        if (listener.name !== "*" && listener.name !== context?.type) {
          return
        }
        setState((prevState: any) => {
          const proposed = listener.function(context, prevState)
          const fromListener = normalizeTicker(proposed)
          const fromContext = resolveTickerFromContext(context)
          const nextState = fromListener ?? fromContext
          return nextState ?? prevState
        })
      })
      if (source === "channel-sync" && isInstrumentContext(context)) {
        console.info("[fdc3] Polygon channel-sync context", {
          mode: modeProps.name,
          ticker: resolveTickerFromContext(context),
        })
      }
    }

    const resolveAgent = async (): Promise<any> => {
      const injected = (window as any)?.fdc3
      if (injected?.addContextListener || injected?.addIntentListener) {
        return injected
      }
      return await getAgent()
    }

    const ensureUserChannel = async (fdc3: any): Promise<any> => {
      if (
        typeof fdc3?.getCurrentChannel !== "function" ||
        typeof fdc3?.getUserChannels !== "function" ||
        typeof fdc3?.joinUserChannel !== "function"
      ) {
        return await Promise.resolve(fdc3?.getCurrentChannel?.())
      }
      const current = await Promise.resolve(fdc3.getCurrentChannel())
      if (current?.id) {
        return current
      }
      const channels = await Promise.resolve(fdc3.getUserChannels())
      const first = Array.isArray(channels) ? channels[0] : undefined
      if (!first?.id) {
        return null
      }
      await Promise.resolve(fdc3.joinUserChannel(first.id))
      return await Promise.resolve(fdc3.getCurrentChannel())
    }

    const syncFromCurrentChannel = async (fdc3: any) => {
      const channel = await ensureUserChannel(fdc3)
      if (channel?.getCurrentContext) {
        const context = await Promise.resolve(channel.getCurrentContext("fdc3.instrument"))
        applyContext(context, "channel-sync")
        return
      }
      if (typeof fdc3?.getCurrentContext === "function") {
        const context = await Promise.resolve(fdc3.getCurrentContext("fdc3.instrument"))
        applyContext(context, "channel-sync")
      }
    }

    const connect = async () => {
      try {
        const fdc3 = await resolveAgent()
        if (disposed) return

        for (const intent of modeProps.intents) {
          const handle = await Promise.resolve(
            fdc3?.addIntentListener?.(intent.name, (context: any) => {
              setState((prevState: any) => {
                const proposed = intent.function(context, prevState)
                const fromIntent = normalizeTicker(proposed)
                const fromContext = resolveTickerFromContext(context)
                const nextState = fromIntent ?? fromContext
                return nextState ?? prevState
              })
            }),
          )
          if (handle?.unsubscribe) handles.push(handle)
        }

        for (const listener of modeProps.listeners) {
          const handle = await Promise.resolve(
            fdc3?.addContextListener?.(listener.name, (context: any) => {
              applyContext(context, "listener")
            }),
          )
          if (handle?.unsubscribe) handles.push(handle)
        }

        await syncFromCurrentChannel(fdc3)

        channelChangedHandler = () => {
          syncFromCurrentChannel(fdc3).catch((error) => {
            console.warn("[fdc3] Polygon channel sync failed", {
              mode: modeProps.name,
              error,
            })
          })
        }
        fdc3?.addEventListener?.("userChannelChanged", channelChangedHandler)

        intervalId = window.setInterval(() => {
          syncFromCurrentChannel(fdc3).catch(() => {})
        }, 2000)
      } catch (error) {
        console.warn("[fdc3] Polygon failed to initialize", {
          mode: modeProps.name,
          error,
        })
      }
    }

    connect()

    return () => {
      disposed = true
      handles.forEach((handle) => handle.unsubscribe?.())
      if (intervalId !== undefined) {
        window.clearInterval(intervalId)
      }
      if (channelChangedHandler) {
        resolveAgent()
          .then((fdc3) => {
            fdc3?.removeEventListener?.("userChannelChanged", channelChangedHandler)
          })
          .catch(() => {})
      }
    }
  }, [modeProps])

  useEffect(() => {
    if (!apiKey || !state) {
      return
    }

    const controller = new AbortController()
    const call = modeProps.endpoint(state, apiKey)
    fetch(call, { signal: controller.signal })
      .then(async (response) => {
        const body = await response.json()
        setData(() => body)
      })
      .catch((error) => {
        if (controller.signal.aborted) {
          return
        }
        console.warn("[fdc3] Polygon fetch failed", {
          mode: modeProps.name,
          state,
          error,
        })
      })

    return () => {
      controller.abort()
    }
  }, [state, apiKey, modeProps])

  return (
    <div id="polygon-widget" ref={container}>
      {modeProps.stateRenderer(state)}
      {modeProps.dataRenderer(data)}
      <div className="polygon-widget-copyright">
        <a href="https://www.polygon.io/" rel="noopener nofollow" target="_blank">
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
