import { getAgent } from "@robmoffat/fdc3"
import { memo, useEffect, useRef, useState } from "react"

/* eslint-disable  @typescript-eslint/no-explicit-any */

import { TradingViewMode } from "./common"
import { chartMode } from "./modes/chart"
import { fundamentalsMode } from "./modes/fundamentals"
import { marketDataMode } from "./modes/market-data"
import { symbolInfoMode } from "./modes/symbol-info"
import { tickersMode } from "./modes/tickers"

type Fdc3ListenerHandle = { unsubscribe?: () => void }

const MODES: TradingViewMode[] = [
  chartMode,
  symbolInfoMode,
  fundamentalsMode,
  tickersMode,
  marketDataMode,
]

const isInstrumentContext = (context: any) => context?.type === "fdc3.instrument"

export const TradingViewWidget = ({ mode }: { mode: string }) => {
  const container: any = useRef()
  const modeProps = MODES.find((m) => m.name === mode) ?? MODES[0]
  const [state, setState] = useState(modeProps.initialState)

  useEffect(() => {
    setState(modeProps.initialState)
  }, [modeProps.initialState])

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
        setState((prevState) => {
          const nextState = listener.function(context, prevState)
          return nextState === undefined || nextState === null ? prevState : nextState
        })
      })
      if (source === "channel-sync" && isInstrumentContext(context)) {
        console.info("[fdc3] TradingView channel-sync context", {
          mode: modeProps.name,
          ticker: context?.id?.ticker,
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
              setState((prevState) => {
                const nextState = intent.function(context, prevState)
                return nextState === undefined || nextState === null ? prevState : nextState
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
            console.warn("[fdc3] TradingView channel sync failed", {
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
        console.warn("[fdc3] TradingView failed to initialize", {
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
    let script: HTMLScriptElement | null = null

    script = document.getElementById("tradingview-widget-script") as HTMLScriptElement
    if (script) {
      container.current.removeChild(script)
    }

    script = document.createElement("script")
    container.current.appendChild(script)

    script.id = "tradingview-widget-script"
    script.src = modeProps.script
    script.type = "text/javascript"
    script.async = true
    script.innerHTML = modeProps.innerHTML(state)
  }, [modeProps, state])

  return (
    <div
      className="tradingview-widget-container"
      ref={container}
      style={{ height: "100%", width: "100%" }}
    >
      <div
        className="tradingview-widget-container__widget"
        style={{ height: "calc(100% - 32px)", width: "100%" }}
      ></div>
      <div className="tradingview-widget-copyright">
        <a href="https://www.tradingview.com/" rel="noopener nofollow" target="_blank">
          <span className="blue-text"> Track all markets on TradingView </span>
        </a>
      </div>
    </div>
  )
}

export default memo(TradingViewWidget)
