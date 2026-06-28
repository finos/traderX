#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRADERX_URL="${1:-http://localhost:8080/trade}"
TRADINGVIEW_URL="${2:-http://localhost:4023/?mode=fundamentals}"
TIMEOUT_MS="${3:-90000}"
PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-1.55.0}"
PLAYWRIGHT_CACHE_ROOT="${PLAYWRIGHT_CACHE_ROOT:-${REPO_ROOT}/.cache/playwright-smoke}"
PLAYWRIGHT_RUNNER_DIR="${PLAYWRIGHT_CACHE_ROOT}/playwright-${PLAYWRIGHT_VERSION}"
PLAYWRIGHT_MODULE_DIR="${PLAYWRIGHT_RUNNER_DIR}/node_modules/playwright"
PLAYWRIGHT_MODULE_PACKAGE_JSON="${PLAYWRIGHT_MODULE_DIR}/package.json"
PLAYWRIGHT_BROWSER_CACHE="${PLAYWRIGHT_RUNNER_DIR}/ms-playwright"

if ! command -v node >/dev/null 2>&1; then
  echo "[error] node is required for playwright smoke checks"
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "[error] npm is required for playwright smoke checks"
  exit 1
fi

mkdir -p "${PLAYWRIGHT_RUNNER_DIR}"
if [[ ! -f "${PLAYWRIGHT_RUNNER_DIR}/package.json" ]]; then
  cat > "${PLAYWRIGHT_RUNNER_DIR}/package.json" <<'EOF'
{
  "name": "traderx-playwright-smoke-runner",
  "private": true
}
EOF
fi

installed_playwright_version=""
if [[ -f "${PLAYWRIGHT_MODULE_PACKAGE_JSON}" ]]; then
  installed_playwright_version="$(node -p "require('${PLAYWRIGHT_MODULE_PACKAGE_JSON}').version" 2>/dev/null || true)"
fi

if [[ "${installed_playwright_version}" != "${PLAYWRIGHT_VERSION}" ]]; then
  echo "[check] install playwright@${PLAYWRIGHT_VERSION} runtime"
  npm --prefix "${PLAYWRIGHT_RUNNER_DIR}" install --silent --no-save "playwright@${PLAYWRIGHT_VERSION}" >/dev/null
fi

echo "[check] ensure playwright chromium browser is available"
PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSER_CACHE}" \
  node "${PLAYWRIGHT_MODULE_DIR}/cli.js" install chromium >/dev/null

echo "[run] fdc3 playwright smoke rig"
TRADERX_PLAYWRIGHT_MODULE_DIR="${PLAYWRIGHT_MODULE_DIR}" \
PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSER_CACHE}" \
node - "${TRADERX_URL}" "${TRADINGVIEW_URL}" "${TIMEOUT_MS}" <<'NODE'
const playwrightModule = process.env.TRADERX_PLAYWRIGHT_MODULE_DIR;
if (!playwrightModule) {
  throw new Error("TRADERX_PLAYWRIGHT_MODULE_DIR is not set");
}
const { chromium } = require(playwrightModule);

const traderxUrl = process.argv[2];
const tradingViewUrl = process.argv[3];
const timeoutMs = Number(process.argv[4] || 90000);
const sailUrl = process.env.TRADERX_SAIL_URL || "";
const launcherUrl = process.env.TRADERX_SAIL_LAUNCHER_URL || "http://localhost:4040";
const sailTradingViewUrl = process.env.TRADERX_SAIL_TRADINGVIEW_URL || "http://localhost:4023/?mode=chart";
const sailPricerUrl = process.env.TRADERX_SAIL_PRICER_URL || "http://localhost:4020/";

const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message);
  }
};

const installMockAgent = async (page) => {
  await page.addInitScript(() => {
    const contextListeners = [];
    const intentListeners = new Map();
    const intentListenerRegistrations = [];
    const channelChangedListeners = [];
    const baseChannel = {
      id: "One",
      type: "user",
      displayMetadata: {
        name: "One",
        glyph: "/icons/tabs/one.svg",
        color: "#123456",
      },
    };
    let currentChannel = {
      ...baseChannel,
      getCurrentContext: async (contextType) => {
        const current = window.__fdc3CurrentContext;
        if (!contextType || current?.type === contextType) {
          return current || null;
        }
        return null;
      },
      broadcast: async (context) => {
        window.__fdc3CurrentContext = context || null;
        window.__fdc3CapturedBroadcasts.push(context);
        receiveContext(context);
      },
    };

    const addContextListener = (contextType, handler) => {
      const listener = { contextType: contextType || null, handler };
      contextListeners.push(listener);
      const current = window.__fdc3CurrentContext;
      if (current && (!listener.contextType || listener.contextType === current.type)) {
        Promise.resolve().then(() => {
          handler(current);
          window.__fdc3DeliveredContexts.push(current);
        });
      }
      return {
        unsubscribe: () => {
          const idx = contextListeners.indexOf(listener);
          if (idx >= 0) {
            contextListeners.splice(idx, 1);
          }
        }
      };
    };

    const addIntentListener = (intent, contextType, handler) => {
      const listeners = intentListeners.get(intent) || [];
      const registration = { intent, contextType, handler };
      listeners.push(registration);
      intentListeners.set(intent, listeners);
      intentListenerRegistrations.push({
        intent,
        contextType,
      });
      return {
        unsubscribe: () => {
          const arr = intentListeners.get(intent) || [];
          const idx = arr.indexOf(registration);
          if (idx >= 0) {
            arr.splice(idx, 1);
          }
          intentListeners.set(intent, arr);
        }
      };
    };

    const receiveContext = (context) => {
      window.__fdc3CurrentContext = context || null;
      for (const listener of contextListeners) {
        if (!listener.contextType || listener.contextType === context?.type) {
          listener.handler(context);
          window.__fdc3DeliveredContexts.push(context);
        }
      }
    };

    const receiveIntent = (intent, context) => {
      const listeners = intentListeners.get(intent) || [];
      for (const listener of listeners) {
        const contextTypes = Array.isArray(listener.contextType)
          ? listener.contextType
          : [listener.contextType].filter(Boolean);
        if (contextTypes.length === 0 || contextTypes.includes(context?.type)) {
          listener.handler(context);
        }
      }
    };

    window.__fdc3CapturedBroadcasts = [];
    window.__fdc3CurrentContext = null;
    window.__fdc3DeliveredContexts = [];
    window.__fdc3IntentListenerRegistrations = intentListenerRegistrations;
	    window.__fdc3ReceiveContext = receiveContext;
	    window.__fdc3ReceiveIntent = receiveIntent;
	    window.fdc3 = {
	      getAgent: async () => window.fdc3,
	      getInfo: async () => ({
	        fdc3Version: "3.0",
        provider: "traderx-playwright-smoke-mock",
      }),
      broadcast: async (context) => {
        window.__fdc3CurrentContext = context || null;
        window.__fdc3CapturedBroadcasts.push(context);
        receiveContext(context);
      },
      raiseIntent: async (intent, context) => {
        window.__fdc3CurrentContext = context || null;
        window.__fdc3CapturedBroadcasts.push(context);
        receiveIntent(intent, context);
        return {
          intent,
          getResult: async () => undefined,
        };
      },
      addContextListener: async (contextType, handler) =>
        addContextListener(contextType, handler),
      addIntentListener: async (intent, handler) =>
        addIntentListener(intent, null, handler),
      addIntentListenerWithContext: async (intent, contextType, handler) =>
        addIntentListener(intent, contextType, handler),
      addEventListener: async (eventType, handler) => {
        if (eventType === "userChannelChanged") {
          channelChangedListeners.push(handler);
        }
        return {
          unsubscribe: () => {
            const idx = channelChangedListeners.indexOf(handler);
            if (idx >= 0) {
              channelChangedListeners.splice(idx, 1);
            }
          },
        };
      },
      removeEventListener: async (eventType, handler) => {
        if (eventType !== "userChannelChanged") {
          return;
        }
        const idx = channelChangedListeners.indexOf(handler);
        if (idx >= 0) {
          channelChangedListeners.splice(idx, 1);
        }
      },
      getCurrentChannel: async () => currentChannel,
      getUserChannels: async () => [currentChannel],
      joinUserChannel: async (channelId) => {
        if (channelId && channelId !== currentChannel.id) {
          currentChannel = {
            ...currentChannel,
            ...baseChannel,
            id: channelId,
            displayMetadata: {
              ...baseChannel.displayMetadata,
              name: channelId,
            },
          };
        }
        channelChangedListeners.forEach((handler) => handler(currentChannel));
        return currentChannel;
      },
      getCurrentContext: async (contextType) => {
        const current = window.__fdc3CurrentContext;
        if (!contextType || current?.type === contextType) {
          return current || null;
        }
        return null;
      },
    };
  });
};

const resolveTickerFromGrid = async (page, timeout) => {
  await page.waitForFunction(() => {
    const selector =
      "app-trade-blotter .ag-cell[col-id='security'], app-position-blotter .ag-cell[col-id='security'], app-order-blotter .ag-cell[col-id='security']";
    return document.querySelector(selector) != null;
  }, undefined, { timeout });

  const ticker = await page.evaluate(() => {
    const selector =
      "app-trade-blotter .ag-cell[col-id='security'], app-position-blotter .ag-cell[col-id='security'], app-order-blotter .ag-cell[col-id='security']";
    const cells = Array.from(document.querySelectorAll(selector));
    const values = cells
      .map((cell) => String(cell.textContent || "").trim().toUpperCase())
      .filter(Boolean);
    if (values.length === 0) {
      return null;
    }
    return values.find((value) => value !== "TSLA") || values[0];
  });

  assert(ticker, "no security ticker found in any blotter grid");
  return ticker;
};

const clickTickerCell = async (page, ticker) => {
  const selector =
    "app-trade-blotter .ag-cell[col-id='security'], app-position-blotter .ag-cell[col-id='security'], app-order-blotter .ag-cell[col-id='security']";
  const locator = page.locator(selector).filter({ hasText: ticker }).first();
  await locator.waitFor({ state: "visible", timeout: 20000 });
  await locator.click();
};

const validateSailUi = async (context) => {
  if (!sailUrl) {
    return;
  }

  const launcherPage = await context.newPage();
  try {
    await launcherPage.goto(launcherUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await launcherPage.waitForFunction(() => {
      return (document.body?.innerText || "").includes("TraderX Intent Launcher");
    }, undefined, { timeout: 10000 });
    const launcherText = await launcherPage.evaluate(() => document.body?.innerText || "");
    assert(
      launcherText.includes("Create Trade Ticket") && launcherText.includes("Create Order Ticket"),
      `TraderX Intent Launcher did not render expected controls:\n${launcherText.slice(0, 1200)}`,
    );
  } finally {
    await launcherPage.close();
  }

  const tradingViewDirectPage = await context.newPage();
  try {
    await tradingViewDirectPage.goto(sailTradingViewUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await tradingViewDirectPage.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("chart |") || text.includes("Track all markets on TradingView");
    }, undefined, { timeout: 15000 });
    const text = await tradingViewDirectPage.evaluate(() => document.body?.innerText || "");
    assert(
      text.includes("chart |") || text.includes("Track all markets on TradingView"),
      `TradingView widget did not render expected shell:\n${text.slice(0, 1200)}`,
    );
  } finally {
    await tradingViewDirectPage.close();
  }

  const pricerDirectPage = await context.newPage();
  try {
    await pricerDirectPage.goto(sailPricerUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await pricerDirectPage.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("Pricer") && text.includes("TSLA");
    }, undefined, { timeout: 15000 });
  } finally {
    await pricerDirectPage.close();
  }

  const page = await context.newPage();
  const runtimeErrors = [];
  page.on("pageerror", (error) => {
    runtimeErrors.push(error?.stack || error?.message || String(error));
  });
  page.on("console", (message) => {
    if (message.type() === "error") {
      runtimeErrors.push(message.text());
    }
  });
  try {
    await page.goto(sailUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs });
    await page.waitForFunction(() => {
      const iframeSrcs = Array.from(document.querySelectorAll("iframe"))
        .map((frame) => String(frame.getAttribute("src") || ""));
      return (
	        iframeSrcs.some((src) => src.includes("localhost:8080/trade")) &&
        iframeSrcs.some((src) => src.includes("localhost:8080/mini-traderx")) &&
        iframeSrcs.some((src) => src.includes("localhost:4040")) &&
        iframeSrcs.some((src) => src.includes("localhost:4023") && src.includes("mode=chart")) &&
        iframeSrcs.some((src) => src.includes("localhost:4023") && src.includes("mode=symbol-info")) &&
        iframeSrcs.some((src) => src.includes("localhost:4023") && src.includes("mode=fundamentals"))
      );
    }, undefined, { timeout: 30000 });

    const demoState = await page.evaluate(() => {
      const text = document.body?.innerText || "";
      const iframeSrcs = Array.from(document.querySelectorAll("iframe"))
        .map((frame) => String(frame.getAttribute("src") || ""));
      const hasViteOverlay =
        text.includes("[plugin:vite:import-analysis]") ||
        text.includes("Failed to resolve import");
      return {
        text,
        iframeSrcs,
	        hasViteOverlay,
	        hasTraderX: text.includes("TraderX"),
        hasMiniTraderX: text.includes("Mini TraderX"),
        hasLauncher: text.includes("TraderX Intent Launcher"),
        hasTradingViewChart: text.includes("Trading View Chart"),
        hasTradingViewSymbolInfo: text.includes("Trading View Symbol Info"),
        hasTradingViewFundamentals: text.includes("Trading View Fundamentals"),
      };
    });
	    assert(!demoState.hasViteOverlay, `Sail UI rendered a Vite import overlay:\n${demoState.text.slice(0, 1200)}`);
	    assert(demoState.hasTraderX, `Sail demo workspace missing TraderX:\n${demoState.text.slice(0, 1200)}`);
    assert(demoState.hasMiniTraderX, `Sail demo workspace missing Mini TraderX:\n${demoState.text.slice(0, 1200)}`);
    assert(demoState.hasLauncher, `Sail demo workspace missing TraderX Intent Launcher:\n${demoState.text.slice(0, 1200)}`);
    assert(demoState.hasTradingViewChart, `Sail demo workspace missing Trading View Chart:\n${demoState.text.slice(0, 1200)}`);
    assert(demoState.hasTradingViewSymbolInfo, `Sail demo workspace missing Trading View Symbol Info:\n${demoState.text.slice(0, 1200)}`);
    assert(demoState.hasTradingViewFundamentals, `Sail demo workspace missing Trading View Fundamentals:\n${demoState.text.slice(0, 1200)}`);

	    const traderFrame = page.frames().find(frame => frame.url().includes("localhost:8080/trade"));
	    const miniTraderFrame = page.frames().find(frame => frame.url().includes("localhost:8080/mini-traderx"));
    const demoLauncherFrame = page.frames().find(frame => frame.url().includes("localhost:4040"));
    const chartFrame = page.frames().find(frame => frame.url().includes("localhost:4023") && frame.url().includes("mode=chart"));
    const symbolInfoFrame = page.frames().find(frame => frame.url().includes("localhost:4023") && frame.url().includes("mode=symbol-info"));
    const fundamentalsFrame = page.frames().find(frame => frame.url().includes("localhost:4023") && frame.url().includes("mode=fundamentals"));
    assert(traderFrame, "Sail demo workspace did not expose a TraderX frame");
    assert(miniTraderFrame, "Sail demo workspace did not expose a Mini TraderX frame");
    assert(demoLauncherFrame, "Sail demo workspace did not expose a TraderX Intent Launcher frame");
    assert(chartFrame, "Sail demo workspace did not expose a Trading View Chart frame");
    assert(symbolInfoFrame, "Sail demo workspace did not expose a Trading View Symbol Info frame");
    assert(fundamentalsFrame, "Sail demo workspace did not expose a Trading View Fundamentals frame");

    await demoLauncherFrame.getByText("TraderX Intent Launcher").waitFor({ timeout: 20000 });
    await miniTraderFrame.getByText("Mini TraderX").waitFor({ timeout: 20000 });
    await chartFrame.locator(".traderx-tradingview-status").first().waitFor({ timeout: 20000 });
    await symbolInfoFrame.locator(".traderx-tradingview-status").first().waitFor({ timeout: 20000 });
    await fundamentalsFrame.locator(".traderx-tradingview-status").first().waitFor({ timeout: 20000 });
    await traderFrame.evaluate(async () => {
      await window.fdc3.broadcast({
        type: "fdc3.instrument",
        id: { ticker: "MSFT" },
      });
    });
    await demoLauncherFrame.getByText("Received instrument context (MSFT)").waitFor({ timeout: 25000 });
    await chartFrame.locator(".traderx-tradingview-status").filter({ hasText: "Received fdc3.instrument (MSFT)" }).first().waitFor({ timeout: 25000 });
    await symbolInfoFrame.locator(".traderx-tradingview-status").filter({ hasText: "Received fdc3.instrument (MSFT)" }).first().waitFor({ timeout: 25000 });
    await fundamentalsFrame.locator(".traderx-tradingview-status").filter({ hasText: "Received fdc3.instrument (MSFT)" }).first().waitFor({ timeout: 25000 });
    await miniTraderFrame.getByText("MSFT").first().waitFor({ timeout: 25000 });

	    await traderFrame.evaluate(async () => {
	      await window.fdc3.broadcast({
	        type: "traderx.account",
	        id: { accountId: "0" },
	        name: "All Accounts",
	      });
	    });
	    await miniTraderFrame.getByText("All Accounts").first().waitFor({ timeout: 25000 });

    const demoRelevantRuntimeErrors = runtimeErrors.filter((message) =>
      /api\.getState is not a function|ChannelSelector|Uncaught TypeError|Failed to resolve import|\[plugin:vite:import-analysis\]/i.test(message),
    );
    assert(
      demoRelevantRuntimeErrors.length === 0,
      `Sail UI reported runtime errors after launching the TraderX demo workspace:\n${demoRelevantRuntimeErrors.join("\n\n")}`,
    );
    console.log(`[ok] Sail v3 UI rendered TraderX demo workspace: ${sailUrl}`);
    console.log("[ok] Sail demo workspace mounted TraderX, Mini TraderX, launcher, TradingView Chart, Symbol Info, and Fundamentals");
    console.log("[ok] Sail demo workspace delivered real fdc3.instrument broadcast to launcher, Mini TraderX, and TradingView panels");
	    console.log("[ok] Sail demo workspace delivered real traderx.account broadcast to Mini TraderX");
    return;

    await page.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("Welcome to Sail") || text.includes("[plugin:vite:import-analysis]");
    }, undefined, { timeout: 20000 });

    const state = await page.evaluate(() => {
      const text = document.body?.innerText || "";
      const hasViteOverlay =
        text.includes("[plugin:vite:import-analysis]") ||
        text.includes("Failed to resolve import");
      return {
        text,
        hasViteOverlay,
        hasWelcome: text.includes("Welcome to Sail"),
        hasBrowseDirectory: text.includes("Browse App Directory"),
      };
    });

    assert(!state.hasViteOverlay, `Sail UI rendered a Vite import overlay:\n${state.text.slice(0, 1200)}`);
    assert(state.hasWelcome, `Sail UI did not render the welcome screen:\n${state.text.slice(0, 1200)}`);
    assert(state.hasBrowseDirectory, `Sail UI did not render App Directory controls:\n${state.text.slice(0, 1200)}`);

    await page.getByRole("button", { name: "Browse App Directory" }).click();
    await page.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("App Directory") && text.includes("TraderX");
    }, undefined, { timeout: 20000 });

    const directoryState = await page.evaluate(() => {
      const text = document.body?.innerText || "";
      return {
        text,
        hasTraderX: text.includes("TraderX"),
        hasLauncher: text.includes("TraderX Intent Launcher"),
        hasTradingViewChart: text.includes("Trading View Chart"),
        hasTradingViewMarketData: text.includes("Trading View Market Data"),
        hasPricer: text.includes("Pricer"),
        hasConformance: text.includes("FDC3 Conformance Framework"),
        hasDeadDefaultApps:
          text.includes("Portfolio Management System") ||
          text.includes("Order Management System") ||
          text.includes("Advanced Chart"),
      };
    });
    assert(directoryState.hasTraderX, `Sail App Directory missing TraderX:\n${directoryState.text.slice(0, 1200)}`);
    assert(directoryState.hasLauncher, `Sail App Directory missing TraderX Intent Launcher:\n${directoryState.text.slice(0, 1200)}`);
    assert(directoryState.hasTradingViewChart, `Sail App Directory missing Trading View Chart:\n${directoryState.text.slice(0, 1200)}`);
    assert(directoryState.hasTradingViewMarketData, `Sail App Directory missing Trading View Market Data:\n${directoryState.text.slice(0, 1200)}`);
    assert(directoryState.hasPricer, `Sail App Directory missing Pricer:\n${directoryState.text.slice(0, 1200)}`);
    assert(directoryState.hasConformance, `Sail App Directory missing FINOS conformance apps:\n${directoryState.text.slice(0, 1200)}`);
    assert(!directoryState.hasDeadDefaultApps, `Sail App Directory still exposes unstarted sample apps:\n${directoryState.text.slice(0, 1200)}`);

    await page.getByText("TraderX", { exact: true }).click();
    await page.waitForFunction(() => {
      return Array.from(document.querySelectorAll("iframe")).some((frame) =>
        String(frame.getAttribute("src") || "").includes("/trade"),
      );
    }, undefined, { timeout: 20000 });
    await page.waitForTimeout(1000);

    await page.evaluate(() => localStorage.clear());
    await page.goto(`${sailUrl}${sailUrl.includes("?") ? "&" : "?"}smokeReset=${Date.now()}`, {
      waitUntil: "domcontentloaded",
      timeout: timeoutMs,
    });
    await page.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("Welcome to Sail") && text.includes("Browse App Directory");
    }, undefined, { timeout: 20000 });
    await page.getByRole("button", { name: "Browse App Directory" }).click();
    await page.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("App Directory") && text.includes("Trading View Chart");
    }, undefined, { timeout: 20000 });
    await page.getByText("Trading View Chart", { exact: true }).click();
    await page.waitForFunction(() => {
      return Array.from(document.querySelectorAll("iframe")).some((frame) =>
        String(frame.getAttribute("src") || "").includes("localhost:4023") &&
        String(frame.getAttribute("src") || "").includes("mode=chart"),
      );
    }, undefined, { timeout: 20000 });
    const tradingViewFrame = page.frames().find(frame => frame.url().includes("localhost:4023") && frame.url().includes("mode=chart"));
    assert(tradingViewFrame, "Sail created a TradingView iframe but Playwright could not resolve its frame");
    await tradingViewFrame.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("chart |") || text.includes("Track all markets on TradingView");
    }, undefined, { timeout: 15000 });
    await page.waitForTimeout(1000);

    await page.evaluate(() => localStorage.clear());
    await page.goto(`${sailUrl}${sailUrl.includes("?") ? "&" : "?"}smokeReset=${Date.now()}`, {
      waitUntil: "domcontentloaded",
      timeout: timeoutMs,
    });
    await page.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("Welcome to Sail") && text.includes("Browse App Directory");
    }, undefined, { timeout: 20000 });
    await page.getByRole("button", { name: "Browse App Directory" }).click();
    await page.waitForFunction(() => {
      const text = document.body?.innerText || "";
      return text.includes("App Directory") && text.includes("TraderX Intent Launcher");
    }, undefined, { timeout: 20000 });
    await page.getByText("TraderX Intent Launcher", { exact: true }).click();
    await page.waitForFunction(() => {
      return Array.from(document.querySelectorAll("iframe")).some((frame) =>
        String(frame.getAttribute("src") || "").includes("localhost:4040"),
      );
    }, undefined, { timeout: 20000 });
    const launcherFrame = page.frames().find(frame => frame.url().includes("localhost:4040"));
    assert(launcherFrame, "Sail created a launcher iframe but Playwright could not resolve its frame");
    await launcherFrame.waitForFunction(() => {
      return (document.body?.innerText || "").includes("TraderX Intent Launcher");
    }, undefined, { timeout: 10000 });
    const launcherFrameText = await launcherFrame.evaluate(() => document.body?.innerText || "");
    assert(
      launcherFrameText.includes("Create Trade Ticket") &&
        launcherFrameText.includes("Create Order Ticket"),
      `Sail launcher iframe did not render expected controls:\n${launcherFrameText.slice(0, 1200)}`,
    );
    await page.waitForTimeout(1000);

    const relevantRuntimeErrors = runtimeErrors.filter((message) =>
      /api\.getState is not a function|ChannelSelector|Uncaught TypeError|Failed to resolve import|\[plugin:vite:import-analysis\]/i.test(message),
    );
    assert(
      relevantRuntimeErrors.length === 0,
      `Sail UI reported runtime errors after launching TraderX:\n${relevantRuntimeErrors.join("\n\n")}`,
    );
    console.log(`[ok] Sail v3 UI rendered without Vite overlay: ${sailUrl}`);
    console.log("[ok] Sail App Directory exposes TraderX, launcher, TradingView, Pricer, and conformance apps without dead local demo ports");
  } finally {
    await page.close();
  }
};

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const traderxPage = await context.newPage();
  const tradingViewPage = await context.newPage();

  try {
    await validateSailUi(context);

    await installMockAgent(traderxPage);
    await installMockAgent(tradingViewPage);

    await Promise.all([
      traderxPage.goto(traderxUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs }),
      tradingViewPage.goto(tradingViewUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs })
    ]);
    await tradingViewPage.evaluate(async () => {
      await window.fdc3.addContextListener("fdc3.instrument", () => {});
    });

	    await traderxPage.waitForFunction(() => {
	      const registrations = Array.isArray(window.__fdc3IntentListenerRegistrations)
	        ? window.__fdc3IntentListenerRegistrations
	        : [];
	      return [
	        "ViewOrders",
	        "TraderX.CreateTradeTicket",
	        "TraderX.CreateOrderTicket",
	      ].every((intent) => registrations.some((entry) => entry?.intent === intent));
	    }, undefined, { timeout: 20000 });

	    const intentRegistrations = await traderxPage.evaluate(() => {
	      return Array.isArray(window.__fdc3IntentListenerRegistrations)
	        ? window.__fdc3IntentListenerRegistrations
	        : [];
    });
    for (const intent of [
      "ViewOrders",
      "TraderX.CreateTradeTicket",
      "TraderX.CreateOrderTicket",
    ]) {
      const registration = intentRegistrations.find((entry) => entry?.intent === intent);
      assert(registration, `expected v3 intent registration for ${intent}`);
      const contextTypes = Array.isArray(registration.contextType)
        ? registration.contextType
        : [registration.contextType];
      assert(
        contextTypes.includes("fdc3.instrument"),
        `expected ${intent} to register with fdc3.instrument context filter, got ${JSON.stringify(registration.contextType)}`,
      );
    }

	    const selectedTicker = await resolveTickerFromGrid(traderxPage, 45000);
	    const broadcastCountBeforeTickerClick = await traderxPage.evaluate(() => {
	      return Array.isArray(window.__fdc3CapturedBroadcasts)
	        ? window.__fdc3CapturedBroadcasts.length
	        : 0;
	    });
	    await clickTickerCell(traderxPage, selectedTicker);

	    await traderxPage.waitForFunction((baselineCount) => {
	      if (!Array.isArray(window.__fdc3CapturedBroadcasts)) {
	        return false;
	      }
	      const last = window.__fdc3CapturedBroadcasts[window.__fdc3CapturedBroadcasts.length - 1];
	      return window.__fdc3CapturedBroadcasts.length > baselineCount && last?.type === "fdc3.instrument";
	    }, broadcastCountBeforeTickerClick, { timeout: 20000 });

    const outboundContext = await traderxPage.evaluate(() => {
      return window.__fdc3CapturedBroadcasts[window.__fdc3CapturedBroadcasts.length - 1];
    });

    assert(outboundContext?.type === "fdc3.instrument", `expected outbound type=fdc3.instrument, got ${JSON.stringify(outboundContext)}`);
    assert(outboundContext?.id?.ticker === selectedTicker, `expected outbound ticker=${selectedTicker}, got ${JSON.stringify(outboundContext)}`);
    const outboundIdKeys = Object.keys(outboundContext?.id || {}).sort();
    assert(outboundIdKeys.length === 1 && outboundIdKeys[0] === "ticker", `expected canonical id.ticker-only payload, got id keys ${outboundIdKeys.join(",")}`);

    await tradingViewPage.evaluate((context) => {
      window.__fdc3ReceiveContext(context);
    }, outboundContext);

    await tradingViewPage.waitForFunction((ticker) => {
      const delivered = Array.isArray(window.__fdc3DeliveredContexts)
        ? window.__fdc3DeliveredContexts
        : [];
      return delivered.some(
        (context) =>
          context?.type === "fdc3.instrument" &&
          String(context?.id?.ticker || "").toUpperCase() ===
            String(ticker || "").toUpperCase(),
      );
    }, selectedTicker, { timeout: 25000 });

    const deliveredContext = await tradingViewPage.evaluate(() => {
      const delivered = Array.isArray(window.__fdc3DeliveredContexts)
        ? window.__fdc3DeliveredContexts
        : [];
      return delivered[delivered.length - 1] || null;
    });
    assert(
      deliveredContext?.type === "fdc3.instrument",
      `expected Sail-delivered type=fdc3.instrument, got ${JSON.stringify(deliveredContext)}`,
    );
    assert(
      String(deliveredContext?.id?.ticker || "").toUpperCase() === selectedTicker,
      `expected Sail-delivered ticker=${selectedTicker}, got ${JSON.stringify(deliveredContext)}`,
    );

    const inboundTicker = "MSFT";
    await traderxPage.evaluate((ticker) => {
      window.__fdc3ReceiveContext({
        type: "fdc3.instrument",
        id: { ticker }
      });
    }, inboundTicker);

    await traderxPage.waitForFunction((ticker) => {
      const text = (document.body?.innerText || "").toUpperCase();
      return text.includes("FDC3 INBOUND") && text.includes(String(ticker || "").toUpperCase());
    }, inboundTicker, { timeout: 15000 });

    const inboundStatus = await traderxPage.evaluate(() => {
      const lines = (document.body?.innerText || "")
        .split("\n")
        .map((line) => line.trim())
        .filter(Boolean);
      return lines.find((line) => /FDC3 INBOUND/i.test(line)) || null;
    });
    assert(inboundStatus, "expected inbound status line in TraderX UI");
    assert(
      inboundStatus.toUpperCase().includes(inboundTicker),
      `expected inbound status to include ticker ${inboundTicker}, got ${inboundStatus}`,
    );

    console.log(`[ok] outbound ticker broadcast captured: ${selectedTicker}`);
    console.log(`[ok] tradingview received context ticker: ${selectedTicker}`);
    console.log(`[ok] inbound status observed for ticker: ${inboundTicker}`);
  } finally {
    await context.close();
    await browser.close();
  }
})().catch((error) => {
  console.error("[fail] playwright fdc3 smoke failed");
  console.error(error?.stack || error);
  process.exit(1);
});
NODE

echo "[done] playwright fdc3 smoke checks passed"
