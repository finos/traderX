/*
 * Estate desk-side FDC3 client (Spec 016) — the BankerX+ clearing desk's
 * Web Connection Protocol client, built on the FINOS reference getAgent()
 * implementation (@finos/fdc3-get-agent), same as the executor terminal.
 *
 * Why this file exists (operator regressions 2026-10-20): the desk became the
 * directory launch target ("https://bankerx.synapticchain.xyz/") when the
 * estate moved to the host roots. Until now that page carried NO FDC3 client,
 * so a targeted StartPayment raise could never complete a WCP handshake —
 * the agent's instance-awaits burned their full 10 s budget, the intent only
 * landed via the file-relay fallback, and apply-the-pacs took ~10 s instead
 * of being instant. This client restores the instant, standards path:
 *
 *   1. getAgent() — WCP handshake with the opening Desktop Agent (the
 *      TraderX blotter's fdc3-agent.js). When the desk tab was launched by
 *      the agent, this resolves in one round trip (no timeout burn); on
 *      direct navigation (no opener agent) it rejects and the client exits.
 *   2. addIntentListener("StartPayment") — registers THIS page as the
 *      directory app's intent listener. The FINOS IntentHandler's
 *      pending-intent machinery then delivers raised payments at
 *      MessageChannel speed, whether the desk was already connected or is
 *      being cold-launched by the raise itself.
 *   3. Forwarding — the payment context rides to the F1 embed (the executor
 *      terminal iframe) by postMessage to its origin allowlist; the
 *      terminal's PaymentPanel message handler picks it up on the same tick.
 *   4. Status return — the terminal posts `synaptic.settlementStatus` to the
 *      desk (parent); the desk broadcasts it over the real FDC3 user channel
 *      (blotter addContextListener) and echoes it to the agent's opener
 *      window (blotter postMessage parity listener). No fabrication: the
 *      payload is forwarded verbatim.
 *
 * Build: esbuild IIFE via build-desk-client.mjs → ../fdc3-desk-client.js.
 * Served by the TraderX origin and referenced from the estate desk page.
 */
import { getAgent } from "@finos/fdc3-get-agent";

/** The F1 embed (executor of record) — same origin the desk themes with
 * bx-theme postMessage; the terminal's inbound handler accepts
 * `{ intent: "StartPayment", context }` envelopes. */
const TERMINAL_ORIGIN = "https://fx.synapticchain.xyz";

/** Origins the desk may forward the settlement-status payload TO (the
 * blotter's opener). Terminal frames may only SEND from the executor origin. */
const BLOTTER_ORIGINS = ["https://traderx.synapticchain.xyz", "http://localhost:3001"];
const TERMINAL_SEND_ORIGINS = [TERMINAL_ORIGIN, "https://terminal.synapticchain.xyz"];

let agentRef: any = null;

function findTerminalFrame(): HTMLIFrameElement | null {
  return document.getElementById("f1-terminal-frame") as HTMLIFrameElement | null;
}

/** Cold-launch delivery law (operator live-fire 2026-10-20): on a fresh desk
 * tab the F1 embed (a full Next.js app) mounts seconds AFTER the desk's
 * intent listener does — a context forwarded pre-load is lost with no error,
 * and the payment only lands later via whatever fallback survives. So the
 * desk client holds the latest context (pendingCtx) and forwards the moment
 * the frame reports a real (non-blank, cross-origin-or-not) document.
 * Cross-origin probes: reading location.href of about:blank does NOT throw
 * (same-origin), a loaded cross-origin frame DOES throw — throw means loaded. */
let pendingCtx: unknown = null;

function frameLooksLoaded(frame: HTMLIFrameElement | null): boolean {
  const win = frame?.contentWindow;
  if (!win) return false;
  try {
    const href = win.location.href;
    return !!href && !href.startsWith("about:");
  } catch {
    return true; // cross-origin read refused ⇒ a real document is loaded
  }
}

function tryForwardPending(): boolean {
  if (pendingCtx === null) return false;
  const frame = findTerminalFrame();
  if (!frame || !frameLooksLoaded(frame)) return false;
  frame.contentWindow!.postMessage(
    pendingHold
      ? { intent: "StartPayment", context: pendingCtx, holdForReview: true }
      : { intent: "StartPayment", context: pendingCtx },
    TERMINAL_ORIGIN
  );
  console.info("[EstateDesk] StartPayment context forwarded to F1 terminal (executor of record)", (pendingCtx as any)?.id?.UETR);
  pendingCtx = null;
  pendingHold = false;
  return true;
}

document.addEventListener("DOMContentLoaded", () => {
  findTerminalFrame()?.addEventListener("load", () => { tryForwardPending(); });
});

/** Forward an inbound StartPayment context into the F1 embed. The envelope
 * shape (`intent` + `context`) matches the terminal PaymentPanel's
 * message handler, which already guards against duplicate execution. */
function forwardToTerminal(context: unknown, opts?: { holdForReview?: boolean }): void {
  pendingCtx = context;
  pendingHold = opts?.holdForReview === true;
  tryForwardPending();
}

let pendingHold = false;

/** Terminal → desk status relay: broadcast over the real FDC3 user channel
 * and echo to the agent's opener (blotter postMessage listener). The
 * payload is forwarded verbatim — the desk invents nothing. */
function relaySettlementStatus(payload: any): void {
  if (agentRef && typeof agentRef.broadcast === "function") {
    try {
      void Promise.resolve(agentRef.broadcast(payload)).catch((e: unknown) =>
        console.warn("[EstateDesk] FDC3 broadcast of settlement status failed (non-fatal):", e)
      );
    } catch (e) {
      console.warn("[EstateDesk] FDC3 broadcast of settlement status failed (non-fatal):", e);
    }
  }
  if (typeof window.opener !== "undefined" && window.opener) {
    for (const origin of BLOTTER_ORIGINS) {
      try {
        window.opener.postMessage(payload, origin);
      } catch {
        /* origin not permitted by UA — skipped */
      }
    }
  }
}

window.addEventListener("message", (evt: MessageEvent) => {
  if (!TERMINAL_SEND_ORIGINS.includes(evt.origin)) return;
  const d = evt.data as any;
  if (!d || d.type !== "synaptic.settlementStatus") return;
  relaySettlementStatus(d);
});

/** Standalone dispatch (desk-only demo): with no Desktop Agent the desk
 * page's legacy shim owns window.fdc3, so the estate dispatch (D) raises a
 * local `fdc3_intent_StartPayment` CustomEvent. Route it into the SAME
 * forward mechanism (pendingCtx + frame-load law): no second transport, no
 * duplicated postMessage contract. holdForReview = the demo raise must be
 * VISIBLE but must NOT book — it holds in the terminal's review modal. */
function registerStandaloneDispatch(): void {
  window.addEventListener("fdc3_intent_StartPayment", (evt: Event) => {
    const ctx = (evt as CustomEvent)?.detail;
    if (!ctx) return;
    console.info("[EstateDesk] local StartPayment raised via desk shim (no Desktop Agent) — forwarding to F1 embed", ctx?.id?.UETR ?? ctx?.uetr);
    forwardToTerminal(ctx, { holdForReview: true });
  });
}

async function boot(): Promise<void> {
  // fdc3-get-agent wedge law (operator console receipt 2026-10-21): the
  // library's DesktopAgentPreloadLoader reacts to the BARE presence of
  // window.fdc3 and awaits fdc3.getInfo() on it. The desk's legacy shim
  // carries no getInfo, so prepareSelection throws
  // "TypeError: e.getInfo is not a function" (uncaught, in promise) AND its
  // get() promise never settles — prepareSelection cancels the loader
  // timeout before touching getInfo — wedging boot forever and starving the
  // standalone dispatch path. So when the only fdc3 on the page is a bare
  // shim, never enter getAgent(): run the standalone dispatch path directly.
  const shimAgent = (window as any).fdc3;
  if (shimAgent && typeof shimAgent.getInfo !== "function") {
    console.info("[EstateDesk] no Desktop Agent (desk shim present, no getInfo) — standalone dispatch path");
    registerStandaloneDispatch();
    return;
  }
  try {
    const agent = await getAgent({ timeoutMs: 5000, intentResolver: false, channelSelector: false });
    if (typeof (agent as any)?.addIntentListener !== "function") return;
    agentRef = agent;
    await Promise.resolve(
      agent.addIntentListener("StartPayment", (ctx: any, meta: any) => {
        console.info("[EstateDesk] StartPayment intent received via FDC3 WCP (Desktop Agent protocol)", {
          uetr: ctx?.id?.UETR,
          source: meta?.source?.appId,
        });
        forwardToTerminal(ctx);
      })
    );
    console.info("[EstateDesk] FDC3 client connected over WCP — StartPayment listener registered on the estate desk", {
      provider: (agent as any)?.getInfo?.().implementationMetadata?.provider,
      fdc3Version: (agent as any)?.getInfo?.().implementationMetadata?.fdc3Version,
    });
    // Join the user channel the blotter listens on, matching the executor
    // terminal's own behavior, so status broadcasts share the same channel.
    try {
      void Promise.resolve(agent.joinUserChannel?.("fdc3.channel.1")).catch(() => {});
    } catch {}
  } catch (e) {
    // Expected when the estate is opened without an agent (direct
    // navigation, /estate/ staging, theme probes): the terminal's own
    // getAgent(), message listener and relay poller still cover delivery.
    console.info(
      "[EstateDesk] getAgent() found no desktop agent (expected when opened directly) — desk stays on relay/postMessage parity:",
      (e as Error)?.message ?? e
    );
    registerStandaloneDispatch();
  }
}

if (typeof window !== "undefined") boot();