import { useEffect, useRef, useState } from "react"
import { getAgent } from "@robmoffat/fdc3-get-agent"
import { createRoot } from "react-dom/client"
import styles from "./main.module.css"

type InstrumentContext = {
  type?: string
  id?: Record<string, unknown>
}

type ListenerLike = {
  unsubscribe?: () => void
}

type ChannelLike = {
  id?: string
  broadcast?: (context: InstrumentContext & { traderxAction?: string; traderxActionRequestId?: string }) => Promise<void>
  getCurrentContext?: (contextType?: string) => Promise<InstrumentContext | null>
}

const extractTicker = (context: InstrumentContext | null | undefined) => {
  const raw = context?.id?.ticker
  if (typeof raw !== "string") {
    return null
  }
  const normalized = raw.trim().toUpperCase()
  return normalized.length > 0 ? normalized : null
}

const TraderXIntentLauncher = () => {
  const agentRef = useRef<any>(null)
  const listenersRef = useRef<ListenerLike[]>([])
  const channelChangedHandlerRef = useRef<(() => void) | null>(null)

  const [currentChannelId, setCurrentChannelId] = useState<string>("(none)")
  const [ticker, setTicker] = useState<string | null>(null)
  const [pendingIntent, setPendingIntent] = useState<string | null>(null)

  const applyInstrumentContext = (
    context: InstrumentContext | null | undefined,
    source: "listener" | "listener-wildcard" | "channel-sync",
  ) => {
    const nextTicker = extractTicker(context)
    setTicker(nextTicker)
    console.info("[traderx-intent-launcher] ticker state updated", {
      source,
      nextTicker,
      context,
    })
  }

  const ensureUserChannel = async (agent: any): Promise<ChannelLike | null> => {
    if (
      typeof agent?.getCurrentChannel !== "function" ||
      typeof agent?.getUserChannels !== "function" ||
      typeof agent?.joinUserChannel !== "function"
    ) {
      return (await agent?.getCurrentChannel?.()) ?? null
    }
    const current = await Promise.resolve(agent.getCurrentChannel())
    if (current?.id) {
      return current
    }
    const userChannels = await Promise.resolve(agent.getUserChannels())
    const defaultChannel = Array.isArray(userChannels) ? userChannels[0] : undefined
    if (!defaultChannel?.id) {
      return null
    }
    await Promise.resolve(agent.joinUserChannel(defaultChannel.id))
    const joined = await Promise.resolve(agent.getCurrentChannel())
    return joined ?? defaultChannel
  }

  const syncContextFromChannel = async (agent: any) => {
    const currentChannel = await ensureUserChannel(agent)
    setCurrentChannelId(currentChannel?.id ?? "(none)")
    let context: InstrumentContext | null | undefined
    if (typeof currentChannel?.getCurrentContext === "function") {
      context = await Promise.resolve(currentChannel.getCurrentContext("fdc3.instrument"))
    } else if (typeof agent.getCurrentContext === "function") {
      context = await Promise.resolve(agent.getCurrentContext("fdc3.instrument"))
    }
    applyInstrumentContext(context, "channel-sync")
  }

  useEffect(() => {
    let isMounted = true

    const connect = async () => {
      try {
        const agent =
          ((window as any)?.fdc3?.addContextListener ? (window as any).fdc3 : null) ??
          (await getAgent())
        if (!isMounted) {
          return
        }
        agentRef.current = agent

        await syncContextFromChannel(agent)

        const instrumentListener = await agent.addContextListener?.(
          "fdc3.instrument",
          (context: InstrumentContext) => {
            applyInstrumentContext(context, "listener")
            console.info("[traderx-intent-launcher] received context", context)
          },
        )
        if (instrumentListener?.unsubscribe) {
          listenersRef.current.push(instrumentListener)
        }

        const wildcardListener = await agent.addContextListener?.(
          (context: InstrumentContext) => {
            if (context?.type !== "fdc3.instrument") {
              return
            }
            applyInstrumentContext(context, "listener-wildcard")
            console.info("[traderx-intent-launcher] received wildcard context", context)
          },
        )
        if (wildcardListener?.unsubscribe) {
          listenersRef.current.push(wildcardListener)
        }

        const onChannelChanged = () => {
          syncContextFromChannel(agent).catch((error) => {
            console.warn(
              "[traderx-intent-launcher] channel sync failed after channel change",
              error,
            )
          })
        }
        channelChangedHandlerRef.current = onChannelChanged
        agent.addEventListener?.("userChannelChanged", onChannelChanged)

        const syncInterval = window.setInterval(() => {
          syncContextFromChannel(agent).catch((error) => {
            console.warn("[traderx-intent-launcher] periodic channel sync failed", error)
          })
        }, 2000)

        if (!isMounted) {
          window.clearInterval(syncInterval)
        } else {
          listenersRef.current.push({
            unsubscribe: () => window.clearInterval(syncInterval),
          })
        }
      } catch (error) {
        console.error("[traderx-intent-launcher] failed to connect", error)
      }
    }

    connect()

    return () => {
      isMounted = false
      listenersRef.current.forEach((listener) => listener.unsubscribe?.())
      listenersRef.current = []
      if (agentRef.current && channelChangedHandlerRef.current) {
        agentRef.current.removeEventListener?.(
          "userChannelChanged",
          channelChangedHandlerRef.current,
        )
      }
    }
  }, [])

  const broadcastTicketRequest = async (
    intent: "TraderX.CreateTradeTicket" | "TraderX.CreateOrderTicket",
  ) => {
    if (!agentRef.current || !ticker) {
      return
    }
    setPendingIntent(intent)
    try {
      const currentChannel = await ensureUserChannel(agentRef.current)
      if (!currentChannel || typeof currentChannel.broadcast !== "function") {
        throw new Error("No active user channel available for ticket broadcast")
      }
      const context = {
        type: "fdc3.instrument",
        id: {
          ticker,
        },
        traderxAction: intent,
        traderxActionRequestId: `${Date.now()}-${Math.random().toString(16).slice(2)}`,
      }
      await Promise.resolve(
        currentChannel.broadcast(context),
      )
      console.info("[traderx-intent-launcher] broadcasted ticket request", {
        intent,
        context,
        channelId: currentChannel.id,
      })
    } catch (error) {
      console.error("[traderx-intent-launcher] ticket request broadcast failed", error)
    } finally {
      setPendingIntent(null)
    }
  }

  const controlsDisabled = !ticker || pendingIntent !== null

  return (
    <div className={styles.launcher}>
      <h2 className={styles.title}>TraderX Intent Launcher 🚀</h2>
      <p className={styles.metaLine}>
        <strong>Channel:</strong> {currentChannelId}
        <span className={styles.separator}>|</span>
        <strong>Ticker:</strong>{" "}
        <span className={styles.ticker}>{ticker ?? "No instrument selected"}</span>
      </p>
      <div className={styles.buttonRow}>
        <button
          type="button"
          className={`${styles.button} ${styles.trade}`}
          disabled={controlsDisabled}
          onClick={() => broadcastTicketRequest("TraderX.CreateTradeTicket")}
        >
          📝 Create Trade Ticket
        </button>
        <button
          type="button"
          className={`${styles.button} ${styles.order}`}
          disabled={controlsDisabled}
          onClick={() => broadcastTicketRequest("TraderX.CreateOrderTicket")}
        >
          📦 Create Order Ticket
        </button>
      </div>
    </div>
  )
}

const container = document.getElementById("app")
if (!container) {
  throw new Error("Missing #app container")
}

createRoot(container).render(<TraderXIntentLauncher />)
