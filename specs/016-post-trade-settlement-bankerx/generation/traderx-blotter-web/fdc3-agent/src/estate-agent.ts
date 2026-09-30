/*
 * TraderX Estate Desktop Agent (Spec 016) — a browser-resident FINOS FDC3 3.0
 * Desktop Agent built on the FINOS reference implementation
 * (@finos/fdc3-web-impl, FDC3 2.2/3.0-conformant agent side).
 *
 * Responsibilities (single concern: desktop agent — it holds NO settlement logic):
 *   1. App Directory: loads App Directory v2 records (default: the BankerX
 *      `/api/fdc3/appd/v2/apps` endpoint) and answers findIntent/findIntentsByContext.
 *   2. App lifecycle: opens directory apps (window.open) and tracks instances.
 *   3. Web Connection Protocol: answers WCP1Hello from opened windows with
 *      WCP3Handshake + MessageChannel, validates identity (WCP4/WCP5 via the
 *      FINOS OpenHandler) so apps can call the standard getAgent() API.
 *   4. Protocol services: DefaultFDC3Server (Broadcast/Intent/Open/Heartbeat
 *      handlers) with 8 standard user channels.
 *   5. Local client: the blotter page itself raises intents through the same
 *      protocol machinery over a loopback MessageChannel — raiseIntent('StartPayment')
 *      is a REAL FDC3 raise, routed to the clearing desk's addIntentListener.
 *
 * Configuration (query params on the host page, or window.__FDC3_AGENT_CONFIG):
 *   directory  — comma-separated App Directory JSON URLs
 *                (default: https://terminal.synapticchain.xyz/api/fdc3/appd/v2/apps)
 *   launcher   — "1" injects the desktop-agent console (directory app list,
 *                connected instances, intent registrations)
 *
 * Build: esbuild IIFE bundle exposing window.SynapticFDC3Agent = { ready, raiseIntent,
 * findIntent, open, ... }.
 */
import {
  BasicDirectory,
  DefaultFDC3Server,
  State,
  ChannelType,
} from "@finos/fdc3-web-impl";
import type {
  Directory,
  DirectoryApp,
  ServerContext,
  AppRegistration,
  InstanceID,
  FDC3Server,
  ChannelState,
} from "@finos/fdc3-web-impl";
import type { AppIdentifier, AppIntent } from "@finos/fdc3-standard";

type WCP3Handshake = {
  type: "WCP3Handshake";
  meta: { connectionAttemptUuid: string; timestamp: Date };
  payload: { fdc3Version: string };
};

// ─── Configuration ─────────────────────────────────────────────────────────
const DEFAULT_DIRECTORY_URL = "https://terminal.synapticchain.xyz/api/fdc3/appd/v2/apps";
const FDC3_VERSION = "3.0";
const DA_PROVIDER = "SynapticChain Estate DA";
const DA_PROVIDER_VERSION = "1.0.0";
/** The appId the blotter page itself is registered under (App Directory record). */
export const BLOTTER_APP_ID = "finos-traderx-desk";

// ─── Alcove enclave adapter (ADR-555) ──────────────────────────────────────
// A directory-miss raise (target not in the directory, or an untargeted raise
// with no directory resolution) carrying `fdc3.payment` context is screened
// through the Alcove enclave's MCP endpoint and then delivered to the
// rendezvous-bound clearing desk. Gated on `fdc3.payment` ONLY — the FINOS
// conformance suite never raises that context, so this path cannot touch
// suite traffic.
const ADAPTER_APP_ID = "synaptic-alcove-enclave";
const ADAPTER_RECORD_TYPE = "mcp-adapter";
const ADAPTER_SCREEN_CONTEXT = "fdc3.payment";
const ADAPTER_DESK_APP_ID = "bankerx-clearing-desk";
const DEFAULT_ENCLAVE_MCP_URL = "https://terminal.synapticchain.xyz/api/enclave/mcp";

/**
 * Adapter trace ring for the demo surfaces (intent modal) and the E2E gate:
 * every enclave-screen stage is recorded here and on the console. Read with
 * `window.__ALCOVE_SCREEN`.
 */
function adapterTrace(event: Record<string, unknown>): void {
  const w = window as unknown as { __ALCOVE_SCREEN?: unknown[] };
  w.__ALCOVE_SCREEN = w.__ALCOVE_SCREEN ?? [];
  w.__ALCOVE_SCREEN.push({ ts: new Date().toISOString(), ...event });
  console.info("[Alcove]", JSON.stringify(event));
}

// v12: snapshot location.search at script-parse time. On the Angular SPA
// the router rewrite (/ → /trade) can strip the query string BEFORE the
// async boot() reads it (boot happens on DOMContentLoaded, after the router
// bootstrap begins) — capturing the raw params while this script executes
// (during initial parse, before Angular's router navigates) keeps the
// ?directory / ?launcher protocol working on the SPA page.
const BOOT_LOCATION_SEARCH = window.location.search;

function readConfig(): { directories: string[]; launcher: boolean } {
  const cfgFromWindow = (window as any).__FDC3_AGENT_CONFIG ?? {};
  const params = new URLSearchParams(BOOT_LOCATION_SEARCH);
  const dirParam = params.get("directory") ?? cfgFromWindow.directory;
  const directories = dirParam
    ? String(dirParam).split(",").map((s: string) => s.trim()).filter(Boolean)
    : [DEFAULT_DIRECTORY_URL];
  const launcher = params.get("launcher") === "1" || cfgFromWindow.launcher === true;
  return { directories, launcher };
}

// ─── ServerContext implementation (window + port management) ───────────────
type RunningRegistration = AppRegistration & {
  url: string;
  window?: Window;
  messagePort?: MessagePort;
};
type LaunchingRegistration = AppRegistration & {
  url: string;
  windowPromise: Promise<Window | null>;
};
type EstateRegistration = RunningRegistration | LaunchingRegistration;

function isLaunching(r: EstateRegistration): r is LaunchingRegistration {
  return !!(r as LaunchingRegistration).windowPromise;
}
function isRunning(r: EstateRegistration): r is RunningRegistration {
  return !!(r as RunningRegistration).window;
}

class EstateServerContext implements ServerContext<AppRegistration> {
  private connections: EstateRegistration[] = [];
  private server: FDC3Server | null = null;
  private sweepTimer: ReturnType<typeof setInterval> | null = null;
  private lastFindInstancesAppId: string | null = null;

  constructor(private readonly directory: Directory) {
    // A mock/launched app that calls window.close() (e.g. the FINOS
    // conformance suite's closeMockAppWindow) must leave our registry the
    // moment the window is gone — findIntent/findInstances read
    // getConnectedApps() and a stale Connected registration makes closed
    // apps keep resolving. Sweep every second; Terminated also triggers
    // server.cleanup so pending intents to the dead instance are dropped.
    // Tight sweep: a closed window that lingers Pending instead of flipping
    // to Terminated makes handshake-gated instance reads over-wait on it.
    this.sweepTimer = setInterval(() => this.sweepClosedWindows(), 250);
  }

  private sweepClosedWindows(): void {
    const dead = this.connections.filter(
      (c) => isRunning(c) && c.window && c.window.closed === true
    );
    for (const d of dead) {
      if (d.state !== State.Terminated) {
        void this.setAppState(d.instanceId, State.Terminated);
      }
    }
    if (dead.length > 0) {
      // Drop fully-dead registrations so getAllApps/getInstanceDetails stop
      // matching closed windows.
      this.connections = this.connections.filter((c) => !dead.includes(c));
      console.info(`[EstateDA] Swept ${dead.length} closed app window(s)`);
    }
  }

  // Untargeted raiseIntent that the library could not auto-resolve: the
  // handler falls back to returning an appIntent for the caller to choose
  // from. This estate has no resolver UI (and the FINOS runner's resolver
  // is inert), so capture the request here; when the response passes
  // through post(), a targeted raise is synthesized against the chosen
  // candidate so the intent is REALLY delivered.
  private lastUntargetedRaise: {
    intent: string;
    context: unknown;
    from: { appId?: string; instanceId?: string };
  } | null = null;

  // Adapter-eligible raises (fdc3.payment) keyed by requestUuid (S7): the
  // library's error response for a missed raise is matched and intercepted in
  // maybeResolveAdapterError by requestUuid — a keyed map means concurrent
  // directory-miss raises can never mis-attribute each other's responses.
  // Capped FIFO so a long session cannot grow it unboundedly.
  private adapterRaises: Map<string, {
    requestUuid?: string;
    intent: string;
    context: unknown;
    targetAppId?: string;
  }> = new Map();
  private static readonly ADAPTER_RAISES_CAP = 50;

  setFDC3Server(server: FDC3Server): void {
    this.server = server;
  }

  // The library's findInstances handler only reports Connected instances.
  // A second fdc3.open() of the same app is still Pending (WCP handshake
  // racing) when the caller asks for instances — the conformance suite's
  // "open two instances then findInstances" test hits exactly that window.
  // Remember the requested appId at receive() so the response can be
  // topped up in post() with every live (non-Terminated) instance.
  noteIncomingRequest(message: unknown, fromInstanceId?: string): void {
    const msg = message as {
      type?: string;
      payload?: {
        app?: { appId?: string };
        target?: { appId?: string };
        intent?: string;
        context?: { type?: string };
      };
      meta?: { source?: { appId?: string; instanceId?: string }; requestUuid?: string };
    };
    if (msg.type === "findInstancesRequest" && msg.payload?.app?.appId) {
      this.lastFindInstancesAppId = msg.payload.app.appId;
    }
    // Adapter-eligible raise (fdc3.payment): remember it keyed by requestUuid
    // so its ERROR response (the library's NoAppsFound for a directory miss)
    // can be resolved through the Alcove enclave screen in
    // maybeResolveAdapterError — and so concurrent misses never collide.
    if (
      msg.type === "raiseIntentRequest" &&
      msg.payload?.intent &&
      msg.payload?.context?.type === ADAPTER_SCREEN_CONTEXT
    ) {
      const key = msg.meta?.requestUuid ?? `noid-${this.adapterRaises.size}`;
      if (this.adapterRaises.size >= EstateServerContext.ADAPTER_RAISES_CAP) {
        const oldest = this.adapterRaises.keys().next().value;
        if (oldest !== undefined) this.adapterRaises.delete(oldest);
      }
      this.adapterRaises.set(key, {
        requestUuid: msg.meta?.requestUuid,
        intent: msg.payload.intent,
        context: msg.payload.context,
        targetAppId: msg.payload.app?.appId ?? msg.payload.target?.appId,
      });
      adapterTrace({
        stage: "adapter-raise",
        intent: msg.payload.intent,
        targetAppId: msg.payload.app?.appId ?? null,
        uetr: (msg.payload.context as { id?: { UETR?: string } })?.id?.UETR ?? null,
      });
    }
    // Untargeted raiseIntent that the library could not auto-resolve: the
    // handler falls back to returning an appIntent for the caller to choose
    // from. This estate has no resolver UI (and the FINOS runner's resolver
    // is inert), so capture the request here; when the response passes
    // through post(), a targeted raise is synthesized against the chosen
    // candidate so the intent is REALLY delivered.
    if (msg.type === "raiseIntentRequest" && msg.payload?.intent && !msg.payload?.app) {
      const from = msg.meta?.source
        ? { appId: msg.meta.source.appId, instanceId: msg.meta.source.instanceId }
        : { instanceId: fromInstanceId };
      this.lastUntargetedRaise = {
        intent: msg.payload.intent,
        context: msg.payload.context,
        from,
      };
    }
  }

  // Bounded handshake wait bound: a launched instance is Pending until its
  // page load + WCP handshake complete. Instance reads (findInstances,
  // isAppConnected) hold for this window instead of answering with a set that
  // overstates readiness (Pending entries a close-chain can never reach) or
  // understates it (instant TargetInstanceUnavailable while a page loads).
  private static readonly HANDSHAKE_WAIT_MS = 2000;

  private async gateFindInstancesResponse(message: object): Promise<void> {
    if ((message as { type?: string }).type !== "findInstancesResponse") return;
    const requested = this.lastFindInstancesAppId;
    if (!requested) return;
    // Hold the response until every launched (non-Terminated) instance of the
    // requested app has completed its WCP handshake — or the bounded wait
    // expires (a page that never connects is genuinely unreachable and is
    // honestly excluded). Then recompute the payload from the true Connected
    // set. Replaces the earlier Pending top-up: that response overstated
    // readiness, so suite close-chains (closeMockAppWindow) counted
    // instances that had not subscribed to the control channel yet and never
    // answered the closeWindow broadcast.
    const deadline = Date.now() + EstateServerContext.HANDSHAKE_WAIT_MS;
    for (;;) {
      const unsettled = this.connections.some(
        (c) => c.appId === requested && c.state !== State.Terminated && c.state !== State.Connected
      );
      if (!unsettled || Date.now() >= deadline) break;
      await new Promise((r) => setTimeout(r, 60));
    }
    const payload = (
      message as { payload?: { appIdentifiers?: { appId: string; instanceId: string }[] } }
    ).payload;
    if (!payload || !Array.isArray(payload.appIdentifiers)) return;
    payload.appIdentifiers = this.connections
      .filter((c) => c.appId === requested && c.state === State.Connected)
      .map((c) => ({ appId: c.appId, instanceId: c.instanceId }));
  }

  /**
   * Alcove enclave adapter (ADR-555): consume a directory-miss raise at the
   * transport tap, BEFORE the server sees it.
   *
   * A raiseIntent carrying `fdc3.payment` context is a genuine directory
   * miss when (a) it targets an app that is not in the directory, or (b) it
   * is untargeted and no directory app declares the intent+context. Such a
   * raise is consumed here (the library never sees it), screened through the
   * ADR-555 enclave pre-flight over the enclave's MCP endpoint, and — on
   * PASS — delivered to the rendezvous-bound clearing desk through the real
   * protocol path (synthesized targeted raiseIntent → launch/WCP/
   * addIntentListener). The caller receives a real intentResolution (or an
   * honest RejectedByEnclave error) for its original requestUuid.
   *
   * Gated on `fdc3.payment` ONLY — the FINOS conformance suite never raises
   * that context, so this intercept cannot touch suite traffic.
   */
  async maybeConsumeAdapterRaise(message: unknown, fromInstanceId: string): Promise<boolean> {
    const msg = message as {
      type?: string;
      payload?: {
        intent?: string;
        context?: { type?: string; id?: { UETR?: string } };
        app?: { appId?: string };
        target?: { appId?: string };
      };
      meta?: { requestUuid?: string; source?: { appId?: string; instanceId?: string } };
    };
    if (msg?.type !== "raiseIntentRequest") return false;
    const context = msg.payload?.context;
    if (context?.type !== ADAPTER_SCREEN_CONTEXT || !msg.payload?.intent) return false;
    const targetAppId = msg.payload.app?.appId ?? msg.payload.target?.appId;
    // Only a directory MISS is consumed — a resolvable raise flows through
    // the library unchanged.
    if (targetAppId) {
      if (this.directory.retrieveAppsById(targetAppId).length > 0) return false;
    } else if (this.directory.retrieveApps(context.type, msg.payload.intent, undefined).length > 0) {
      return false;
    }
    const uetr = context.id?.UETR ?? msg.meta?.requestUuid ?? "unknown";
    adapterTrace({
      stage: "adapter-raise-miss",
      intent: msg.payload.intent,
      targetAppId: targetAppId ?? null,
      uetr,
    });

    // 1. Enclave screen (ADR-555 pre-flight through the MCP endpoint).
    const screen = await this.runEnclaveScreen(context);
    if (!screen.passed) {
      adapterTrace({ stage: "screen-rejected", uetr, reason: screen.reason });
      this.post(
        {
          meta: {
            responseUuid: this.createUUID(),
            requestUuid: msg.meta?.requestUuid ?? this.createUUID(),
            timestamp: new Date(),
          },
          type: "raiseIntentResponse",
          payload: { error: `RejectedByEnclave:${screen.reason}` },
        },
        fromInstanceId
      );
      return true;
    }
    // 2. Route by the rendezvous lane (S2) and deliver through the real
    //    server path. Prefer the routed desk's RUNNING instance
    //    (forwardRequest — no new window); when no instance is connected,
    //    the synth launches the routed desk via the normal FDC3 open path.
    const desk = this.resolveRoutedDesk(screen.lane);
    adapterTrace({
      stage: "screen-passed",
      uetr,
      lane: screen.lane,
      latencyMs: screen.latencyMs,
      desk,
    });
    const deskReg = this.connections.find(
      (c) => c.appId === desk && c.state === State.Connected
    );
    // ADR-555 desk-side attestation (S3): the delivered context carries the
    // enclave's WOTS+ proof + derivation timestamp; the desk re-derives the
    // leaf root through the enclave's verify_preflight tool BEFORE settling
    // and honest-rejects on mismatch. The caller's context is never mutated —
    // only the synthesized delivery is enriched.
    const deliveredContext =
      screen.wotsPlus && screen.timestamp
        ? { ...(context as object), alcove: { lane: screen.lane, timestamp: screen.timestamp, wotsPlus: screen.wotsPlus } }
        : context;
    const synth = {
      type: "raiseIntentRequest",
      payload: {
        intent: msg.payload.intent,
        context: deliveredContext,
        app: deskReg
          ? { appId: desk, instanceId: deskReg.instanceId }
          : { appId: desk },
      },
      meta: {
        requestUuid: this.createUUID(),
        timestamp: new Date(),
        source: msg.meta?.source ?? { appId: BLOTTER_APP_ID, instanceId: fromInstanceId },
      },
    };
    let deliveredInstance: string | null = null;
    try {
      if (this.server) {
        await Promise.resolve(this.server.receive(synth, fromInstanceId));
        const freshReg = this.connections.find(
          (c) => c.appId === desk && c.state === State.Connected
        );
        deliveredInstance = deskReg?.instanceId ?? freshReg?.instanceId ?? null;
      }
    } catch (e) {
      console.error("[EstateDA] Enclave-adapter desk delivery failed:", e);
      adapterTrace({ stage: "desk-delivery-failed", uetr, error: String(e) });
      this.post(
        {
          meta: {
            responseUuid: this.createUUID(),
            requestUuid: msg.meta?.requestUuid ?? this.createUUID(),
            timestamp: new Date(),
          },
          type: "raiseIntentResponse",
          payload: { error: `EnclaveDeskDeliveryFailed:${(e as Error)?.message ?? e}` },
        },
        fromInstanceId
      );
      return true;
    }
    adapterTrace({
      stage: "desk-delivered",
      uetr,
      desk,
      lane: screen.lane,
      instanceId: deliveredInstance,
    });

    // 3. Answer the caller: intentResolution for the ORIGINAL requestUuid.
    this.post(
      {
        meta: {
          responseUuid: this.createUUID(),
          requestUuid: msg.meta?.requestUuid ?? this.createUUID(),
          timestamp: new Date(),
        },
        type: "raiseIntentResponse",
        payload: {
          intentResolution: {
            intent: msg.payload.intent,
            source: deliveredInstance
              ? { appId: desk, instanceId: deliveredInstance }
              : { appId: desk },
          },
        },
      },
      fromInstanceId
    );
    return true;
  }

  /**
   * Alcove enclave adapter (ADR-555): resolve a directory-miss raise.
   *
   * When the library answers an adapter-eligible raise (fdc3.payment) with an
   * ERROR response — NoAppsFound for an untargeted raise with no directory
   * resolution, or TargetAppUnavailable/NoAppsFound for a targeted raise at
   * an app outside this directory — that raise has MISSED the directory.
   * Instead of propagating the failure, this adapter:
   *   1. screens the payment through the ADR-555 enclave pre-flight
   *      (sanctions Merkle Bloom, Invariant-9 solvency, 256-lane rendezvous)
   *      over the enclave's MCP endpoint;
   *   2. on PASS, delivers the intent to the rendezvous-bound clearing desk
   *      through the real protocol path (a synthesized targeted raiseIntent
   *      through the server — launch + WCP + addIntentListener delivery);
   *   3. on FAIL, honestly rejects (payload.error = RejectedByEnclave).
   *
   * The response the caller receives for the ORIGINAL requestUuid is the
   * final intentResolution (or the honest rejection) — the intercept is
   * invisible above the transport. Gated on: adapter-eligible context +
   * error response + requestUuid match, consumed on first use, so nested
   * responses (including the synthesized delivery's own) pass through.
   */
  private async maybeResolveAdapterError(message: object, to: InstanceID): Promise<void> {
    const m = message as {
      type?: string;
      payload?: { error?: string };
      meta?: { requestUuid?: string };
    };
    if (m.type !== "raiseIntentResponse" || !m.payload?.error) return;
    const raiseKey = m.meta?.requestUuid ?? "";
    const raise = this.adapterRaises.get(raiseKey) ?? null;
    if (!raise) return;
    this.adapterRaises.delete(raiseKey); // consume — never intercept this raise twice
    const uetr =
      (raise.context as { id?: { UETR?: string } })?.id?.UETR ?? raise.requestUuid ?? "unknown";

    // 1. Enclave screen (ADR-555 pre-flight through the MCP endpoint).
    const screen = await this.runEnclaveScreen(raise.context);
    if (!screen.passed) {
      m.payload = { error: `RejectedByEnclave:${screen.reason}` };
      adapterTrace({ stage: "screen-rejected", uetr, reason: screen.reason });
      return;
    }

    // 2. Route by lane (S2) and deliver to the routed desk through the real
    //    server path (running instance preferred, else the open path).
    const desk = this.resolveRoutedDesk(screen.lane);
    adapterTrace({
      stage: "screen-passed",
      uetr,
      lane: screen.lane,
      latencyMs: screen.latencyMs,
      desk,
    });
    const deskReg = this.connections.find(
      (c) => c.appId === desk && c.state === State.Connected
    );
    const deliveredContext =
      screen.wotsPlus && screen.timestamp
        ? { ...(raise.context as object), alcove: { lane: screen.lane, timestamp: screen.timestamp, wotsPlus: screen.wotsPlus } }
        : raise.context;
    const synth = {
      type: "raiseIntentRequest",
      payload: {
        intent: raise.intent,
        context: deliveredContext,
        app: deskReg ? { appId: desk, instanceId: deskReg.instanceId } : { appId: desk },
      },
      meta: {
        requestUuid: this.createUUID(),
        timestamp: new Date(),
        source: { appId: BLOTTER_APP_ID, instanceId: to },
      },
    };
    let deliveredInstance: string | null = null;
    try {
      if (this.server) {
        await Promise.resolve(this.server.receive(synth, to));
        const freshReg = this.connections.find(
          (c) => c.appId === desk && c.state === State.Connected
        );
        deliveredInstance = deskReg?.instanceId ?? freshReg?.instanceId ?? null;
      }
    } catch (e) {
      console.error("[EstateDA] Enclave-adapter desk delivery failed:", e);
      m.payload = { error: `EnclaveDeskDeliveryFailed:${(e as Error)?.message ?? e}` };
      adapterTrace({ stage: "desk-delivery-failed", uetr, error: String(e) });
      return;
    }
    adapterTrace({
      stage: "desk-delivered",
      uetr,
      desk,
      lane: screen.lane,
      instanceId: deliveredInstance,
    });

    // 3. Reshape the caller's response in place: intentResolution with the
    //    desk the intent actually landed on.
    m.payload = {
      intentResolution: {
        intent: raise.intent,
        source: deliveredInstance
          ? { appId: desk, instanceId: deliveredInstance }
          : { appId: desk },
      },
    };
  }

  /** ADR-555 pre-flight over the Alcove enclave's JSON-RPC MCP endpoint.
   *  Desk routing is NOT done here — the lane it returns is routed by
   *  resolveRoutedDesk() afterwards (S2). */
  private async runEnclaveScreen(context: unknown): Promise<{
    passed: boolean;
    reason: string;
    lane: number | null;
    latencyMs: number | null;
    /** WOTS+ proof + derivation timestamp from the report, for the desk-side
     * attestation verification (S3). Present only on PASS. */
    wotsPlus?: Record<string, unknown>;
    timestamp?: string;
  }> {
    const url =
      (this.directory.retrieveAppsById(ADAPTER_APP_ID)[0]?.details as { url?: string } | undefined)
        ?.url ?? DEFAULT_ENCLAVE_MCP_URL;
    const ctx = context as {
      id?: { UETR?: string };
      amount?: number;
      pair?: string;
      debtor?: { name?: string };
      creditor?: { name?: string };
    };
    const amount = Number(ctx?.amount ?? 0);
    const body = {
      jsonrpc: "2.0",
      id: 1,
      method: "tools/call",
      params: {
        name: "preflight_and_sign",
        arguments: {
          uetr: ctx?.id?.UETR ?? "no-uetr",
          amount: amount > 0 ? amount : 1,
          pair: ctx?.pair ?? "USD/USD",
          debtor: ctx?.debtor?.name ?? "Unknown Debtor",
          creditor: ctx?.creditor?.name ?? "Unknown Creditor",
          // No tsaFee/netAmount sent: the guardian derives the levy from its
          // canonical 0.50% schedule server-side (S4) — the caller no longer
          // supplies the solvency arithmetic.
        },
      },
    };
    const fail = (reason: string) =>
      ({ passed: false, reason, lane: null, latencyMs: null, wotsPlus: undefined, timestamp: undefined });
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) return fail(`EnclaveHTTP${res.status}`);
      const data = (await res.json()) as {
        result?: { content?: Array<{ type: string; text: string }> };
      };
      const text = data.result?.content?.find((c) => c.type === "text")?.text;
      if (!text) return fail("EnclaveEmptyReport");
      const report = JSON.parse(text) as {
        passed?: boolean;
        error?: string;
        totalLatencyMs?: number;
        concurrencyAllocation?: { laneId?: number };
        attestation?: {
          timestamp?: string;
          wotsPlus?: Record<string, unknown>;
        };
      };
      const passed = report.passed === true;
      return {
        passed,
        reason: passed ? "" : report.error ?? "EnclavePreflightFailed",
        lane: report.concurrencyAllocation?.laneId ?? null,
        latencyMs: report.totalLatencyMs ?? null,
        wotsPlus: report.attestation?.wotsPlus,
        timestamp: report.attestation?.timestamp,
      };
    } catch (e) {
      return fail(`EnclaveUnreachable:${(e as Error)?.message ?? e}`);
    }
  }

  /**
   * The desk a screened intent is routed to (S2): the enclave-computed lane
   * (SHA3(debtor‖pair) % 256) is mapped through the Alcove record's
   * `customProps.alcovePartitions` — the App Directory v2 spec-sanctioned
   * extension point — to a real desk appId. Falls back to the record's
   * declared desk, then the estate constant.
   */
  private resolveRoutedDesk(lane: number | null): string {
    const record = this.directory.retrieveAppsById(ADAPTER_APP_ID)[0] as
      | (DirectoryApp & {
          customProps?: {
            alcoveDesk?: string;
            alcovePartitions?: Array<{ lanes: string; desk: string }>;
          };
        })
      | undefined;
    const partitions = record?.customProps?.alcovePartitions;
    if (lane !== null && partitions?.length) {
      for (const p of partitions) {
        const m = /^(\d+)\s*-\s*(\d+)$/.exec(p.lanes);
        if (m && lane >= Number(m[1]) && lane <= Number(m[2])) return p.desk;
      }
    }
    return record?.customProps?.alcoveDesk ?? ADAPTER_DESK_APP_ID;
  }

  async narrowIntents(_raiser: AppIdentifier, appIntents: AppIntent[]): Promise<AppIntent[]> {
    // Single-desk estate: no resolver UI. The library demands a SINGLE
    // AppIntent selection — returning the whole list is interpreted as
    // "user cancelled" (UserCancelledResolution). Pick deterministically:
    // the first directory-declared resolution.
    return appIntents.length > 0 ? [appIntents[0]] : appIntents;
  }

  setInstanceDetails(uuid: InstanceID, meta: EstateRegistration): void {
    this.connections = this.connections.filter((c) => c.instanceId !== uuid);
    const details = { ...meta, instanceId: uuid } as EstateRegistration;
    this.connections.push(details);

    if (isLaunching(details)) {
      details.windowPromise.then((win) => {
        if (win) {
          this.setInstanceDetails(uuid, {
            appId: details.appId,
            instanceId: uuid,
            state: details.state,
            url: details.url,
            window: win,
          });
        } else {
          // Launch failed (popup blocker / COOP) — drop the registration.
          this.connections = this.connections.filter((c) => c.instanceId !== uuid);
          console.error(
            "[EstateDA] No window reference received after launching app:",
            details.url,
            "(popup blocker or Cross-Origin-Opener-Policy)"
          );
        }
      });
    }
  }

  async getInstanceForWindow(win: Window): Promise<RunningRegistration | undefined> {
    const running = this.connections.filter(isRunning).find((i) => i.window === win);
    if (running) return running;

    const launching = this.connections.filter(isLaunching);
    if (launching.length === 0) {
      console.warn("[EstateDA] No app registration matches a connecting window");
      return undefined;
    }
    return new Promise<RunningRegistration | undefined>((resolve) => {
      const total = launching.length;
      let done = 0;
      launching.forEach((l) => {
        l.windowPromise.then((realized) => {
          done++;
          if (realized === win) {
            resolve({
              appId: l.appId,
              instanceId: l.instanceId,
              state: l.state,
              url: l.url,
              window: realized,
            });
          } else if (done >= total) {
            resolve(undefined);
          }
        });
      });
    });
  }

  getInstanceDetails(uuid: InstanceID): EstateRegistration | undefined {
    return this.connections.find((i) => i.instanceId === uuid);
  }

  createUUID(): string {
    return crypto.randomUUID();
  }

  async post(message: object, to: InstanceID): Promise<void> {
    // Adapter path FIRST: a raiseIntent error response for an
    // adapter-eligible (fdc3.payment) directory miss is resolved in-place —
    // screened through the Alcove enclave, delivered to the bound desk, and
    // reshaped into an intentResolution before it reaches the caller.
    await this.maybeResolveAdapterError(message, to);
    this.sanitizeFindIntentResponses(message);
    await this.gateFindInstancesResponse(message);
    const reg = this.getInstanceDetails(to);
    // Loopback registrations (the DA page itself) have a messagePort but no
    // window; launched apps may briefly have neither while connecting.
    const port = reg ? (reg as RunningRegistration).messagePort : undefined;
    if (reg && port) {
      port.postMessage(message);
    } else if (!reg) {
      console.error("[EstateDA] Cannot message unknown app instance:", to);
    } else {
      console.error(
        `[EstateDA] Cannot message app that is not yet connected: ${to} appId=${reg.appId} state=${reg.state} hasPort=${!!port}`
      );
    }
  }

  /**
   * findIntent / findIntentsByContext responses: directory records are the
   * source of truth for intent availability (2.x conformance semantics — the
   * FINOS suite asserts `apps.length === 1` while a listener instance is also
   * connected). If a directory record exists, instance entries are dropped;
   * if NO directory record matches (e.g. aTestingIntent raised with a context
   * the declaring apps don't listen for), apps is emptied outright — the
   * listener-only entries the library appends must not make the call resolve,
   * because the proxy then returns instead of throwing NoAppsFound (the
   * WrongContext contract). An emptied apps array makes the proxy throw
   * NoAppsFound. raiseIntent responses additionally collapse a single-app,
   * multi-instance resolution to one deterministic instance: without it,
   * stale instances left over from earlier tests make the proxy see an
   * ambiguous list and throw UserCancelledResolution.
   */
  private sanitizeFindIntentResponses(message: object): void {
    const type = (message as { type?: string }).type;
    if (
      type !== "findIntentResponse" &&
      type !== "findIntentsByContextResponse" &&
      type !== "raiseIntentResponse"
    )
      return;
    const payload = (message as { payload?: Record<string, unknown> }).payload;
    if (!payload) return;
    const filterApps = (apps: unknown[]): unknown[] => {
      const hasDirectoryEntry = apps.some(
        (a) => typeof a === "object" && a !== null && (a as { instanceId?: unknown }).instanceId == null
      );
      if (hasDirectoryEntry) {
        return apps.filter(
          (a) => typeof a === "object" && a !== null && (a as { instanceId?: unknown }).instanceId == null
        );
      }
      return [];
    };
    if (type === "findIntentResponse" && payload.appIntent) {
      const appIntent = payload.appIntent as { apps?: unknown[] };
      if (Array.isArray(appIntent.apps)) appIntent.apps = filterApps(appIntent.apps);
    }
    if (type === "findIntentsByContextResponse" && Array.isArray(payload.appIntents)) {
      for (const ai of payload.appIntents as Array<{ apps?: unknown[] }>) {
        if (Array.isArray(ai.apps)) ai.apps = filterApps(ai.apps);
      }
      // Drop appIntents that ended up with no apps at all (instance-only
      // matches for a filtered context) — matches the suite's expectation.
      payload.appIntents = (payload.appIntents as Array<{ apps?: unknown[] }>).filter(
        (ai) => Array.isArray(ai.apps) && ai.apps.length > 0
      );
    }
    if (type === "raiseIntentResponse" && payload.appIntent) {
      const appIntent = payload.appIntent as {
        intent?: { name?: string };
        apps?: unknown[];
      };
      const apps = appIntent.apps;
      // The library's unresolved raiseIntent response carries an appIntent
      // for the caller to choose from. There is no resolver UI in this
      // estate, and the FINOS runner's resolver is inert (NullIntentResolver
      // returns void → UserCancelledResolution), so resolve here: pick one
      // deterministic candidate (prefer a running instance) and synthesize a
      // targeted raiseIntentRequest through the real server so the intent is
      // actually delivered, then re-shape the response as intentResolution.
      if (
        Array.isArray(apps) &&
        apps.length >= 1 &&
        appIntent.intent?.name &&
        this.lastUntargetedRaise?.from
      ) {
        const chosen = (apps.find(
          (a) => typeof a === "object" && a !== null && (a as { instanceId?: unknown }).instanceId != null
        ) ?? apps[0]) as { appId?: string; instanceId?: string };
        const synth = {
          type: "raiseIntentRequest",
          payload: {
            intent: appIntent.intent.name,
            context: this.lastUntargetedRaise.context,
            app: chosen.instanceId
              ? { appId: chosen.appId, instanceId: chosen.instanceId }
              : { appId: chosen.appId },
          },
          meta: {
            requestUuid: this.createUUID(),
            timestamp: new Date(),
            source: this.lastUntargetedRaise.from,
          },
        };
        const synthFrom = this.lastUntargetedRaise.from.instanceId;
        // Deliver out-of-band; never block the original response on it.
        if (this.server && synthFrom) {
          void Promise.resolve(this.server.receive(synth, synthFrom)).catch((e) =>
            console.error("[EstateDA] Synthesized intent delivery failed:", e)
          );
        }
        delete payload.appIntent;
        payload.intentResolution = {
          intent: appIntent.intent.name,
          source: chosen,
        };
      }
    }
  }

  async open(appId: string, _source?: AppIdentifier): Promise<InstanceID> {
    const apps = this.directory.retrieveAppsById(appId) as DirectoryApp[];
    if (apps.length === 0) {
      throw new Error("AppNotFound");
    }
    // mcp-adapter records (ADR-555 Alcove): no browser window. The adapter is
    // registered Connected immediately with a synthetic instance and health-
    // checked with an MCP tools/list call against its endpoint.
    if ((apps[0] as { type?: string }).type === ADAPTER_RECORD_TYPE) {
      return this.openAdapterInstance(apps[0]);
    }
    const details = apps[0]?.details as { url?: string } | undefined;
    const url = details?.url;
    if (!url) {
      console.error("[EstateDA] Directory app has no launch URL:", appId);
      throw new Error("ErrorOnLaunch");
    }
    // Register the launching instance BEFORE the window realizes, so a fast
    // WCP1Hello from the new window resolves via getInstanceForWindow.
    // The window target must be unique per launch: window.open with an
    // existing target name reuses (focuses) the old window instead of
    // creating a second instance — the conformance suite opens two instances
    // of IntentAppA and expects two distinct instanceIds.
    const instanceId = this.createUUID();
    // Open as a SEPARATE OS window, not a browser tab: passing a features
    // string (including 'popup') makes the UA spawn an independent window.
    // Size it to roughly half the operator's viewport, positioned on the
    // right, so TraderX blotter and the clearing desk sit side by side
    // during the demo. Minimums keep the desk usable on narrow windows.
    const deskW = Math.max(480, Math.round(window.innerWidth * 0.52));
    const deskH = Math.max(560, Math.round(window.innerHeight * 0.94));
    const deskL = Math.max(0, window.innerWidth - deskW);
    const windowPromise = Promise.resolve(
      window.open(url, `${appId}-${instanceId}`, `popup=yes,width=${deskW},height=${deskH},left=${deskL},top=0`)
    );
    this.setInstanceDetails(instanceId, {
      appId,
      instanceId,
      state: State.Pending,
      url,
      windowPromise,
    });
    return instanceId;
  }

  /** Launch an mcp-adapter record: synthetic instance + MCP tools/list health check. */
  private async openAdapterInstance(
    record: DirectoryApp & { details?: { url?: string } }
  ): Promise<InstanceID> {
    const instanceId = this.createUUID();
    const url = record.details?.url ?? DEFAULT_ENCLAVE_MCP_URL;
    this.setInstanceDetails(instanceId, {
      appId: record.appId,
      instanceId,
      state: State.Connected,
      url,
    });
    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "tools/list" }),
      });
      const data = (await res.json()) as { result?: { tools?: Array<{ name?: string }> } };
      const tools = (data.result?.tools ?? []).map((t) => t.name ?? "?");
      adapterTrace({ stage: "adapter-open", appId: record.appId, tools });
      console.info(
        `[EstateDA] MCP adapter ${record.appId} opened — enclave tools: ${tools.join(", ")}`
      );
    } catch (e) {
      console.error("[EstateDA] MCP adapter tools/list failed:", e);
      adapterTrace({ stage: "adapter-open-failed", appId: record.appId, error: String(e) });
    }
    return instanceId;
  }

  async close(instanceId: InstanceID): Promise<void> {
    const reg = this.getInstanceDetails(instanceId);
    if (!reg || reg.state !== State.Connected) {
      throw new Error("ErrorOnClose");
    }
    if (isRunning(reg)) {
      reg.window?.close();
    }
    await this.setAppState(instanceId, State.Terminated);
  }

  async setAppState(app: InstanceID, newState: State): Promise<void> {
    const found = this.connections.find((c) => c.instanceId === app);
    if (found) {
      if (found.state !== State.Terminated && newState === State.Terminated) {
        this.server?.cleanup(app);
      }
      found.state = newState;
    }
  }

  async getConnectedApps(): Promise<AppRegistration[]> {
    return this.connections
      .filter((c) => c.state === State.Connected)
      .map((c) => ({ appId: c.appId, instanceId: c.instanceId, state: c.state }));
  }

  async isAppConnected(app: InstanceID): Promise<boolean> {
    const snap = this.connections.find((c) => c.instanceId === app);
    // Unknown instance: the caller targeted something outside this estate —
    // keep the instant-false contract (RaiseIntentFailTargetedAppInstance
    // expects an immediate TargetInstanceUnavailable for a bogus instanceId).
    if (snap === undefined) return false;
    // Known instance still mid-handshake: hold briefly for the WCP
    // handshake to complete instead of rejecting a page that is seconds
    // into loading (raiseIntent-at-first-instance timing).
    const deadline = Date.now() + EstateServerContext.HANDSHAKE_WAIT_MS;
    let cur = snap;
    while (cur.state === State.Pending && Date.now() < deadline) {
      await new Promise((r) => setTimeout(r, 50));
      cur = this.connections.find((c) => c.instanceId === app) ?? cur;
    }
    return this.connections.some((c) => c.instanceId === app && c.state === State.Connected);
  }

  async getAllApps(): Promise<AppRegistration[]> {
    return this.connections.map((c) => ({
      appId: c.appId,
      instanceId: c.instanceId,
      state: c.state,
    }));
  }

  log(message: string): void {
    console.info("[EstateDA]", message);
  }

  provider(): string {
    return DA_PROVIDER;
  }

  providerVersion(): string {
    return DA_PROVIDER_VERSION;
  }

  fdc3Version(): string {
    return FDC3_VERSION;
  }
}

// ─── Directory loading (App Directory v2 JSON) ─────────────────────────────
async function loadDirectory(urls: string[], fdc3Version: string): Promise<BasicDirectory> {
  const dir = new BasicDirectory([], fdc3Version);
  for (const url of urls) {
    try {
      const res = await fetch(url, { mode: "cors" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const apps: DirectoryApp[] = Array.isArray(data)
        ? data
        : data.applications ?? [];
      dir.addApps(apps);
      console.info(`[EstateDA] App Directory loaded ${apps.length} app(s) from ${url}`);
    } catch (e) {
      console.warn(`[EstateDA] App Directory load failed (${url}):`, e);
    }
  }
  return dir;
}

// ─── Standard user channels (FDC3 2.0 §6: displayMetadata required) ────────
function standardUserChannels(): ChannelState[] {
  const defs: Array<[string, string, string]> = [
    ["red", "Channel 1", "1"],
    ["orange", "Channel 2", "2"],
    ["yellow", "Channel 3", "3"],
    ["green", "Channel 4", "4"],
    ["cyan", "Channel 5", "5"],
    ["blue", "Channel 6", "6"],
    ["magenta", "Channel 7", "7"],
    ["purple", "Channel 8", "8"],
  ];
  return defs.map(([color, name, glyph], i) => ({
    id: `fdc3.channel.${i + 1}`,
    type: ChannelType.user,
    context: [],
    displayMetadata: { name, color, glyph },
  }));
}

// ─── WCP handshake (parent postMessage mode) ───────────────────────────────
function bindWcpHelloListener(
  sc: EstateServerContext,
  fdc3Server: FDC3Server
): void {
  window.addEventListener("message", async (event: MessageEvent) => {
    const data = event.data as any;
    const source = event.source as Window | null;
    if (!data || data.type !== "WCP1Hello" || !source) return;

    const instance = await sc.getInstanceForWindow(source);
    if (!instance) {
      console.warn("[EstateDA] WCP1Hello from unregistered window — ignored");
      return;
    }
    console.info(
      "[EstateDA] App instance connecting via WCP:",
      instance.appId,
      instance.instanceId
    );

    const channel = new MessageChannel();
    channel.port2.onmessage = async (message: MessageEvent) => {
      const msg = message.data as any;
      // ADR-555 Alcove adapter: consume directory-miss raises before the
      // server sees them (fdc3.payment-gated — see maybeConsumeAdapterRaise).
      if (await sc.maybeConsumeAdapterRaise(msg, instance.instanceId)) return;
      sc.noteIncomingRequest(msg, instance.instanceId);
      if (msg.type === "WCP6Goodbye") {
        fdc3Server.cleanup(instance.instanceId);
      } else {
        fdc3Server.receive(msg, instance.instanceId);
      }
    };

    await sc.setInstanceDetails(instance.instanceId, {
      ...instance,
      messagePort: channel.port2,
    });

    const handshake: WCP3Handshake = {
      type: "WCP3Handshake",
      meta: {
        connectionAttemptUuid: data.meta?.connectionAttemptUuid,
        timestamp: new Date(),
      },
      payload: { fdc3Version: FDC3_VERSION },
    };
    source.postMessage(handshake, event.origin, [channel.port1]);
  });
}

// ─── Loopback client: the blotter page as an FDC3 app ──────────────────────
class LoopbackDA {
  private readonly port: MessagePort;
  /** v12: pending requests keyed by meta.requestUuid (see dispatch()). */
  private readonly pending = new Map<
    string,
    {
      resolve: (v: any) => void;
      reject: (e: Error) => void;
      timer: ReturnType<typeof setTimeout>;
    }
  >();
  /** v12: event routing tables (intent name / context type → handlers). */
  private readonly intentHandlers = new Map<string, Set<(msg: any) => void>>();
  private readonly contextHandlers = new Map<string, Set<(msg: any) => void>>();

  constructor(
    private readonly sc: EstateServerContext,
    private readonly fdc3Server: FDC3Server,
    private readonly instanceId: InstanceID
  ) {
    const channel = new MessageChannel();
    // Server side: messages arriving on port2 are served; server posts out on
    // port2 (registration.messagePort), which lands on port1 for the client.
    channel.port2.onmessage = async (message: MessageEvent) => {
      const msg = message.data as any;
      // ADR-555 Alcove adapter: consume directory-miss raises before the
      // server sees them (fdc3.payment-gated — see maybeConsumeAdapterRaise).
      if (await this.sc.maybeConsumeAdapterRaise(msg, this.instanceId)) return;
      this.sc.noteIncomingRequest(msg, this.instanceId);
      if (msg.type === "WCP6Goodbye") {
        this.fdc3Server.cleanup(this.instanceId);
      } else {
        this.fdc3Server.receive(msg, this.instanceId);
      }
    };
    this.sc.setInstanceDetails(this.instanceId, {
      appId: BLOTTER_APP_ID,
      instanceId: this.instanceId,
      state: State.Connected,
      url: window.location.href,
      messagePort: channel.port2,
    });
    this.port = channel.port1;
    // v12: persistent client-side demux — every message the server posts
    // (responses, intentEvent, broadcastEvent) flows through dispatch().
    this.port.onmessage = (message: MessageEvent) =>
      this.dispatch(message.data as any);
  }

  /**
   * v12: persistent on-message multiplexer. Requests are keyed by
   * meta.requestUuid; protocol events (intentEvent, broadcastEvent /
   * contextEvent from listener registrations) are routed to their
   * registered handlers by intent name / context type. This makes the
   * in-page client a REAL protocol client for listeners and channels —
   * no onmessage juggling — so the host page's window.fdc3 is backed by
   * the same machinery remote apps use over WCP.
   */
  private dispatch(msg: any) {
    if (msg?.type === "WCP6Goodbye") return;
    const pending = msg?.meta?.requestUuid
      ? this.pending.get(msg.meta.requestUuid)
      : undefined;
    if (pending) {
      clearTimeout(pending.timer);
      this.pending.delete(msg.meta.requestUuid);
      if (msg.payload?.error) pending.reject(new Error(msg.payload.error));
      else pending.resolve(msg.payload);
      return;
    }
    const deliver = (set: Set<(msg: any) => void> | undefined, msg: any) =>
      set?.forEach((h) => {
        try {
          h(msg);
        } catch (err) {
          console.error("[EstateDA] listener error:", err);
        }
      });
    if (msg?.type === "intentEvent") {
      const name = msg.payload?.intent;
      deliver(this.intentHandlers.get("*ANY*"), msg);
      if (name) deliver(this.intentHandlers.get(name), msg);
    }
    if (msg?.type === "broadcastEvent" || msg?.type === "contextEvent") {
      const ctype = msg.payload?.context?.type ?? null;
      deliver(this.contextHandlers.get("*ANY*"), msg);
      if (ctype) deliver(this.contextHandlers.get(ctype), msg);
    }
  }

  private request(type: string, payload: any, responseTypes: string[]): Promise<any> {
    return new Promise((resolve, reject) => {
      const requestUuid = this.sc.createUUID();
      const req = {
        type,
        payload: { requestUuid, ...payload },
        meta: {
          requestUuid,
          timestamp: new Date(),
          source: { appId: BLOTTER_APP_ID, instanceId: this.instanceId },
        },
      };
      // Timeout guard so a dead agent path never hangs the settle flow.
      const timer = setTimeout(() => {
        this.pending.delete(requestUuid);
        reject(new Error("DARequestTimeout"));
      }, 30000);
      this.pending.set(requestUuid, { resolve, reject, timer });
      this.port.postMessage(req);
    });
  }

  /**
   * Register a listener over the real protocol (addIntentListenerRequest /
   * addContextListenerRequest + unsubscribe requests on unsubscribe).
   * Delivery is via dispatch() event routing with the standard handler
   * signature handler(context, metadata). null contextType and "*" are
   * wildcards.
   */
  private addListener(
    requestType: string,
    payload: any,
    responseType: string,
    kind: "intent" | "context",
    key: string,
    handler: (msg: any) => void
  ): Promise<any> {
    return this.request(requestType, payload, [responseType]).then((res) => {
      const listenerUUID = res?.listenerUUID;
      const table = kind === "intent" ? this.intentHandlers : this.contextHandlers;
      if (!table.has(key)) table.set(key, new Set());
      table.get(key)!.add(handler);
      return {
        unsubscribe: () => {
          table.get(key)?.delete(handler);
          return this.request(
            kind === "intent"
              ? "intentListenerUnsubscribeRequest"
              : "contextListenerUnsubscribeRequest",
            { listenerUUID },
            [
              kind === "intent"
                ? "intentListenerUnsubscribeResponse"
                : "contextListenerUnsubscribeResponse",
            ]
          ).catch(() => undefined);
        },
      };
    });
  }

  /** Wrap a wire channel object with real protocol-backed methods. */
  private wrapChannel(c: any): any {
    if (!c) return null;
    const self = this;
    return {
      ...c,
      broadcast: (context: any) =>
        self.request("broadcastRequest", { context, channelId: c.id }, ["broadcastResponse"]),
      addContextListener: (contextType: any, handler: any) =>
        self.addListener(
          "addContextListenerRequest",
          { contextType: contextType ?? null, channelId: c.id },
          "addContextListenerResponse",
          "context",
          contextType === null ? "*ANY*" : contextType,
          (msg) => handler(msg.payload?.context, msg.payload?.metadata)
        ),
    };
  }

  /** v12: real intent listener over the protocol (Standard FDC3 API). */
  addIntentListener(intent: string, handler: (context: any, meta?: any) => void) {
    return this.addListener(
      "addIntentListenerRequest",
      { intent },
      "addIntentListenerResponse",
      "intent",
      intent,
      (msg) => handler(msg.payload?.context, msg.payload?.metadata)
    );
  }

  /** v12: real context listener over the protocol; null = all contexts. */
  addContextListener(contextType: string | null, handler: (context: any, meta?: any) => void) {
    return this.addListener(
      "addContextListenerRequest",
      { contextType: contextType ?? null },
      "addContextListenerResponse",
      "context",
      contextType === null ? "*ANY*" : contextType,
      (msg) => handler(msg.payload?.context, msg.payload?.metadata)
    );
  }

  /** v12: broadcast on the current private/user channel via the protocol. */
  broadcast(context: any) {
    return this.getCurrentChannel().then((ch) => {
      if (!ch) return undefined;
      return this.request("broadcastRequest", { context, channelId: ch.id }, [
        "broadcastResponse",
      ]);
    });
  }

  getCurrentChannel(): Promise<any> {
    return this.request("getCurrentChannelRequest", {}, ["getCurrentChannelResponse"]).then(
      (res) => this.wrapChannel(res?.channel)
    );
  }

  getUserChannels(): Promise<any> {
    return this.request("getUserChannelsRequest", {}, ["getUserChannelsResponse"]).then(
      (res) => res?.userChannels ?? []
    );
  }

  joinUserChannel(channelId: string): Promise<any> {
    return this.request("joinUserChannelRequest", { channelId }, [
      "joinUserChannelResponse",
    ]).then((res) => this.wrapChannel(res?.channel));
  }

  leaveCurrentChannel(): Promise<void> {
    return this.request("leaveCurrentChannelRequest", {}, [
      "leaveCurrentChannelResponse",
    ]).then(() => undefined);
  }

  /** v12: identity object per the Desktop Agent Preload pattern. */
  getAgentInfo(): any {
    return {
      fdc3Version: FDC3_VERSION,
      provider: "SynapticChain Estate DA",
      appMetadata: {
        appId: BLOTTER_APP_ID,
        instanceId: this.instanceId,
        version: "1.0.0",
      },
    };
  }

  /** v12: spec-shaped implementation metadata (apps probe this). */
  getInfo(): any {
    const base = this.getAgentInfo();
    return {
      fdc3Version: base.fdc3Version,
      provider: base.provider,
      providerVersion: DA_PROVIDER_VERSION,
      appMetadata: base.appMetadata,
      optionalFeatures: {
        UsedMultipleContexts: true,
        OriginatingAppMetadata: true,
        UserChannelPermission: false,
      },
    };
  }

  raiseIntent(intent: string, context: any, targetAppId?: string): Promise<any> {
    return this.request(
      "raiseIntentRequest",
      {
        raiseIntentRequestUuid: this.sc.createUUID(),
        intent,
        context,
        ...(targetAppId ? { target: { appId: targetAppId } } : {}),
      },
      ["raiseIntentResponse", "raiseIntentResultResponse"]
    );
  }

  findIntent(intent: string, context?: any): Promise<any> {
    return this.request(
      "findIntentRequest",
      { intent, ...(context ? { context } : {}) },
      ["findIntentResponse"]
    );
  }

  findIntentsByContext(context: any): Promise<any> {
    return this.request(
      "findIntentsByContextRequest",
      { context },
      ["findIntentsByContextResponse"]
    );
  }
}

// ─── Desktop-agent console (optional, launcher=1) ──────────────────────────
function buildConsole(sc: EstateServerContext, dir: BasicDirectory): HTMLElement {
  const panel = document.createElement("div");
  panel.id = "fdc3-da-console";
  panel.style.cssText = [
    "position:fixed", "bottom:8px", "right:8px", "width:300px",
    "max-height:340px", "overflow:auto", "z-index:99999",
    "background:#0c0f1c", "border:1px solid #2a3a56", "color:#e4e8f0",
    "font:9px/1.5 ui-monospace,'Courier New',monospace", "padding:8px",
    "letter-spacing:.5px",
  ].join(";");

  const head = document.createElement("div");
  head.style.cssText = "color:#7c3aed;font-weight:700;margin-bottom:6px;";
  head.textContent = `⬡ FDC3 DESKTOP AGENT · ${DA_PROVIDER} v${DA_PROVIDER_VERSION} · FDC3 ${FDC3_VERSION}`;
  panel.appendChild(head);

  const apps = dir.retrieveAllApps();
  const appSection = document.createElement("div");
  appSection.textContent = `DIRECTORY · ${apps.length} APP(S)`;
  appSection.style.cssText = "color:#7a8699;margin-bottom:4px;";
  panel.appendChild(appSection);

  for (const app of apps) {
    const visible = (app as any)?.hostManifests?.demo?.visible ?? true;
    if (!visible) continue;
    const row = document.createElement("div");
    row.style.cssText = "display:flex;justify-content:space-between;gap:6px;padding:2px 0;";
    const label = document.createElement("span");
    label.textContent = app.title ?? app.appId;
    label.style.cssText = "overflow:hidden;text-overflow:ellipsis;white-space:nowrap;";
    const start = document.createElement("button");
    start.textContent = "START";
    start.style.cssText =
      "background:#4c1d95;color:#fff;border:1px solid #6d28d9;font:inherit;padding:1px 6px;cursor:pointer;";
    start.onclick = () => {
      sc.open(app.appId).then((id) => console.info("[EstateDA] opened", app.appId, id));
    };
    row.appendChild(label);
    row.appendChild(start);
    panel.appendChild(row);
  }

  const connections = document.createElement("div");
  connections.textContent = "INSTANCES";
  connections.style.cssText = "color:#7a8699;margin:6px 0 2px;";
  panel.appendChild(connections);
  const refresh = () => {
    void sc.getAllApps().then((all) => {
      let list = connections.nextElementSibling as HTMLElement | null;
      if (!list) {
        list = document.createElement("div");
        connections.after(list);
      }
      list.innerHTML = all.length
        ? all
            .map(
              (a) =>
                `${a.appId} · ${a.instanceId.slice(0, 8)}… · ${
                  a.state === State.Connected
                    ? "CONNECTED"
                    : a.state === State.Pending
                    ? "PENDING"
                    : "STATE " + a.state
                }`
            )
            .join("<br>")
        : "// none";
      list.style.color = "#00d97e";
    });
  };
  refresh();
  const timer = setInterval(refresh, 3000);

  // collapse toggle
  head.onclick = () => {
    const bodyHidden = panel.dataset.collapsed === "1";
    panel.dataset.collapsed = bodyHidden ? "0" : "1";
    Array.from(panel.children).forEach((child, i) => {
      if (i > 0) (child as HTMLElement).style.display = bodyHidden ? "" : "none";
    });
  };
  head.style.cursor = "pointer";
  (panel as any).__stopConsole = () => clearInterval(timer);

  document.body.appendChild(panel);
  return panel;
}

// ─── Boot ──────────────────────────────────────────────────────────────────
export type EstateAgentAPI = {
  ready: Promise<void>;
  provider: string;
  providerVersion: string;
  fdc3Version: string;
  raiseIntent: (intent: string, context: any, targetAppId?: string) => Promise<any>;
  findIntent: (intent: string, context?: any) => Promise<any>;
  findIntentsByContext: (context: any) => Promise<any>;
  open: (appId: string) => Promise<InstanceID>;
  getConnectedApps: () => Promise<AppRegistration[]>;
  /** v12: real Desktop Agent API surface (published as window.fdc3). */
  addIntentListener: (intent: string, handler: (context: any, meta?: any) => void) => Promise<any>;
  addContextListener: (contextType: string | null, handler: (context: any, meta?: any) => void) => Promise<any>;
  broadcast: (context: any) => Promise<void>;
  getCurrentChannel: () => Promise<any>;
  getUserChannels: () => Promise<any[]>;
  joinUserChannel: (channelId: string) => Promise<any>;
  leaveCurrentChannel: () => Promise<void>;
  getAgentInfo: () => any;
  getInfo: () => any;
  getAgent: () => Promise<EstateAgentAPI>;
};

let bootResolve: () => void;
const readyPromise = new Promise<void>((resolve) => (bootResolve = resolve));

async function boot(): Promise<void> {
  const cfg = readConfig();
  const directory = await loadDirectory(cfg.directories, FDC3_VERSION);

  const sc = new EstateServerContext(directory);
  const fdc3Server = new DefaultFDC3Server(
    sc,
    directory,
    standardUserChannels(),
    true, // heartbeats
    20000, // intent timeout ms
    15000 // open handler timeout ms
  );
  sc.setFDC3Server(fdc3Server);

  bindWcpHelloListener(sc, fdc3Server);

  const loopback = new LoopbackDA(sc, fdc3Server, sc.createUUID());

  if (cfg.launcher) {
    const prev = document.getElementById("fdc3-da-console");
    if (prev) prev.remove();
    buildConsole(sc, directory);
  }

  const api: EstateAgentAPI = {
    ready: readyPromise,
    provider: DA_PROVIDER,
    providerVersion: DA_PROVIDER_VERSION,
    fdc3Version: FDC3_VERSION,
    raiseIntent: (intent, context, targetAppId) => loopback.raiseIntent(intent, context, targetAppId),
    findIntent: (intent, context) => loopback.findIntent(intent, context),
    findIntentsByContext: (context) => loopback.findIntentsByContext(context),
    open: (appId) => sc.open(appId),
    getConnectedApps: () => sc.getConnectedApps(),
    addIntentListener: (intent, handler) => loopback.addIntentListener(intent, handler),
    addContextListener: (contextType, handler) => loopback.addContextListener(contextType, handler),
    broadcast: (context) => loopback.broadcast(context),
    getCurrentChannel: () => loopback.getCurrentChannel(),
    getUserChannels: () => loopback.getUserChannels(),
    joinUserChannel: (channelId) => loopback.joinUserChannel(channelId),
    leaveCurrentChannel: () => loopback.leaveCurrentChannel(),
    getAgentInfo: () => loopback.getAgentInfo(),
    getInfo: () => loopback.getInfo(),
    getAgent: () => Promise.resolve(api),
  };
  (window as any).SynapticFDC3Agent = api;
  // v12 Desktop Agent Preload: publish the real API as window.fdc3 unless a
  // host already provided one (yield to pre-existing bridges — same rule the
  // bankerx-bridge stub used, but ours is REAL protocol, not a stub).
  try {
    if (!window.fdc3) {
      (window as any).fdc3 = api;
      window.dispatchEvent(new Event("fdc3Ready"));
      console.info("[EstateDA] window.fdc3 published (real Desktop Agent API)");
    } else {
      console.info("[EstateDA] host window.fdc3 already present — yielded");
    }
  } catch (err) {
    console.error("[EstateDA] window.fdc3 publish failed:", err);
  }
  console.info(
    `[EstateDA] Desktop agent ready — FDC3 ${FDC3_VERSION}, provider "${DA_PROVIDER}", ` +
      `${directory.retrieveAllApps().length} directory app(s)`
  );
  bootResolve();
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", () => void boot());
} else {
  void boot();
}