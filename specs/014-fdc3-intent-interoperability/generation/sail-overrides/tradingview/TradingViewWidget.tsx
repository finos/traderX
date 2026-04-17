// TradingViewWidget.jsx
import { getAgent } from "@robmoffat/fdc3"
import { useEffect, useRef, memo, useState } from "react"

/* eslint-disable  @typescript-eslint/no-explicit-any */

import { TradingViewMode } from "./common"
import { chartMode } from "./modes/chart"
import { symbolInfoMode } from "./modes/symbol-info"
import { fundamentalsMode } from "./modes/fundamentals"
import { tickersMode } from "./modes/tickers"
import { marketDataMode } from "./modes/market-data"

const MODES: TradingViewMode[] = [
  chartMode,
  symbolInfoMode,
  fundamentalsMode,
  tickersMode,
  marketDataMode,
]

export const TradingViewWidget = ({ mode }: { mode: string }) => {
  const container: any = useRef()
  const modeProps = MODES.find((m) => m.name === mode) ?? MODES[0]

  const [state, setState] = useState(modeProps.initialState)

  useEffect(() => {
    setState(modeProps.initialState)
  }, [mode, modeProps.initialState])

  useEffect(() => {
    let cancelled = false
    let unsubscribeFns: Array<() => void> = []
    let activeAgent: any = undefined
    let lastLoggedChannelId: string | null | undefined = undefined
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
          if (lastLoggedChannelId !== current.id) {
            console.info("[fdc3] TradingView channel ready", {
              mode: modeProps.name,
              channelId: current.id,
            })
            lastLoggedChannelId = current.id
          }
          return
        }
        const userChannels = await Promise.resolve(fdc3.getUserChannels())
        const defaultUserChannel = Array.isArray(userChannels)
          ? userChannels[0]
          : undefined
        if (!defaultUserChannel?.id) {
          console.warn("[fdc3] TradingView has no user channels to join", {
            mode: modeProps.name,
          })
          return
        }
        await Promise.resolve(fdc3.joinUserChannel(defaultUserChannel.id))
        const joined = await Promise.resolve(fdc3.getCurrentChannel())
        const channelId = joined?.id ?? defaultUserChannel.id
        if (lastLoggedChannelId !== channelId) {
          console.info("[fdc3] TradingView joined user channel", {
            mode: modeProps.name,
            channelId,
          })
          lastLoggedChannelId = channelId
        }
      } catch (error) {
        console.warn("[fdc3] TradingView failed to ensure user channel", {
          mode: modeProps.name,
          error,
        })
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
      listenerDef: { name: string; function: (context: any, previousState: any) => any },
      context: any,
      sourceType: "context" | "context-wildcard" | "context-poll",
    ) => {
      const signature = contextSignature(context)
      if (signature && signature === lastAppliedContextSignature) {
        return
      }
      if (signature) {
        lastAppliedContextSignature = signature
      }
      console.info("[fdc3] TradingView received context", {
        mode: modeProps.name,
        sourceType,
        sourceName: listenerDef.name,
        context,
      })
      setState((previousState: any) => {
        const newState = listenerDef.function(context, previousState)
        if (newState == null) {
          console.warn("[fdc3] context produced no TradingView symbol", {
            mode: modeProps.name,
            contextType: listenerDef.name,
            context,
          })
          return previousState
        }
        console.info("[fdc3] TradingView resolved symbol", {
          mode: modeProps.name,
          sourceType,
          sourceName: listenerDef.name,
          previousState,
          nextState: newState,
        })
        return newState
      })
    }

    const registerListeners = async (fdc3: any) => {
      const nextUnsubscribes: Array<() => void> = []

      for (const intent of modeProps.intents) {
        const listener = await Promise.resolve(
          fdc3.addIntentListener(intent.name, (context: any) => {
            console.info("[fdc3] TradingView received context", {
              mode: modeProps.name,
              sourceType: "intent",
              sourceName: intent.name,
              context,
            })
            setState((previousState: any) => {
              const newState = intent.function(context, previousState)
              if (newState == null) {
                console.warn("[fdc3] intent produced no TradingView symbol", {
                  mode: modeProps.name,
                  intent: intent.name,
                  context,
                })
                return previousState
              }
              console.info("[fdc3] TradingView resolved symbol", {
                mode: modeProps.name,
                sourceType: "intent",
                sourceName: intent.name,
                previousState,
                nextState: newState,
              })
              return newState
            })
          }),
        )
        if (listener?.unsubscribe) {
          nextUnsubscribes.push(() => listener.unsubscribe())
        }
      }

      for (const listenerDef of modeProps.listeners) {
        const listener = await Promise.resolve(
          fdc3.addContextListener(listenerDef.name, (context: any) => {
            applyModeContext(listenerDef, context, "context")
          }),
        )
        if (listener?.unsubscribe) {
          nextUnsubscribes.push(() => listener.unsubscribe())
        }
      }

      // Tactical fallback for Sail DA inconsistencies: subscribe to wildcard
      // context events in addition to the typed listener.
      const wildcardListener = await Promise.resolve(
        fdc3.addContextListener((context: any) => {
          const contextType = context?.type
          if (!contextType) {
            return
          }
          const matchingListeners = modeProps.listeners.filter(
            (listenerDef) => listenerDef.name === contextType,
          )
          if (matchingListeners.length === 0) {
            return
          }
          matchingListeners.forEach((listenerDef) =>
            applyModeContext(listenerDef, context, "context-wildcard"),
          )
        }),
      )
      if (wildcardListener?.unsubscribe) {
        nextUnsubscribes.push(() => wildcardListener.unsubscribe())
      }

      clearListeners()
      unsubscribeFns = nextUnsubscribes
      activeAgent = fdc3
      console.log("[fdc3] listeners registered", { mode: modeProps.name })
    }

    // Tactical demo fallback: poll the channel's latest instrument context so
    // widgets still react when context listener delivery is intermittently flaky.
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
          currentChannel.getCurrentContext("fdc3.instrument"),
        )
        if (!context) {
          return
        }
        const matchingListeners = modeProps.listeners.filter(
          (listenerDef) => listenerDef.name === "fdc3.instrument",
        )
        matchingListeners.forEach((listenerDef) =>
          applyModeContext(listenerDef, context, "context-poll"),
        )
      } catch (error) {
        console.warn("[fdc3] TradingView channel context sync failed", {
          mode: modeProps.name,
          error,
        })
      }
    }

    const ensureConnected = async () => {
      if (cancelled || registerInFlight) return
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
          console.warn("[fdc3] TradingView listener registration attempt failed", {
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
    const rootEl = container.current as HTMLElement | null
    if (!rootEl) {
      return
    }

    const widgetEl = rootEl.querySelector(
      ".tradingview-widget-container__widget",
    ) as HTMLElement | null
    if (!widgetEl) {
      return
    }

    const priorScript = document.getElementById("tradingview-widget-script")
    if (priorScript) {
      priorScript.remove()
    }

    // Force a clean mount for widgets that do not handle in-place symbol updates.
    widgetEl.innerHTML = ""

    console.info("[fdc3] TradingView widget render", {
      mode: modeProps.name,
      symbol: state,
    })

    const script = document.createElement("script")
    script.id = "tradingview-widget-script"
    script.src = modeProps.script
    script.type = "text/javascript"
    script.async = true
    // nosemgrep: javascript.browser.security.insecure-document-method.insecure-document-method
    script.innerHTML = modeProps.innerHTML(state)

    widgetEl.appendChild(script)
  }, [mode, state])

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
        <a
          href="https://www.tradingview.com/"
          rel="noopener nofollow"
          target="_blank"
        >
          <span className="blue-text"> Track all markets on TradingView </span>
        </a>
      </div>
    </div>
  )
}

export default memo(TradingViewWidget)
