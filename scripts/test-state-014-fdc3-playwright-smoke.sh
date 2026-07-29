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

const assert = (condition, message) => {
  if (!condition) {
    throw new Error(message);
  }
};

const installMockAgent = async (page) => {
  await page.addInitScript(() => {
    const contextListeners = [];
    const intentListeners = new Map();
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
      return {
        unsubscribe: () => {
          const idx = contextListeners.indexOf(listener);
          if (idx >= 0) {
            contextListeners.splice(idx, 1);
          }
        }
      };
    };

    const addIntentListener = (intent, handler) => {
      const listeners = intentListeners.get(intent) || [];
      listeners.push(handler);
      intentListeners.set(intent, listeners);
      return {
        unsubscribe: () => {
          const arr = intentListeners.get(intent) || [];
          const idx = arr.indexOf(handler);
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
      for (const handler of listeners) {
        handler(context);
      }
    };

    window.__fdc3CapturedBroadcasts = [];
    window.__fdc3CurrentContext = null;
    window.__fdc3DeliveredContexts = [];
    window.__fdc3ReceiveContext = receiveContext;
    window.__fdc3ReceiveIntent = receiveIntent;
    window.fdc3 = {
      getInfo: async () => ({
        fdc3Version: "2.2",
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
        return { intent };
      },
      addContextListener: async (contextType, handler) =>
        addContextListener(contextType, handler),
      addIntentListener: async (intent, handler) =>
        addIntentListener(intent, handler),
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

(async () => {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext();
  const traderxPage = await context.newPage();
  const tradingViewPage = await context.newPage();

  try {
    await installMockAgent(traderxPage);
    await installMockAgent(tradingViewPage);

    await Promise.all([
      traderxPage.goto(traderxUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs }),
      tradingViewPage.goto(tradingViewUrl, { waitUntil: "domcontentloaded", timeout: timeoutMs })
    ]);

    await traderxPage.getByText("FDC3 connected", { exact: false }).first().waitFor({ timeout: 20000 });

    const selectedTicker = await resolveTickerFromGrid(traderxPage, 45000);
    await clickTickerCell(traderxPage, selectedTicker);

    await traderxPage.waitForFunction(() => {
      return Array.isArray(window.__fdc3CapturedBroadcasts) && window.__fdc3CapturedBroadcasts.length > 0;
    }, undefined, { timeout: 20000 });

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
      `expected TradingView-delivered type=fdc3.instrument, got ${JSON.stringify(deliveredContext)}`,
    );
    assert(
      String(deliveredContext?.id?.ticker || "").toUpperCase() === selectedTicker,
      `expected TradingView-delivered ticker=${selectedTicker}, got ${JSON.stringify(deliveredContext)}`,
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
