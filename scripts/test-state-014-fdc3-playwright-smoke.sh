#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRADERX_URL="${1:-http://localhost:8080/trade}"
TRADINGVIEW_URL="${2:-http://localhost:4023/?mode=fundamentals}"
TIMEOUT_MS="${3:-90000}"
PLAYWRIGHT_VERSION="${PLAYWRIGHT_VERSION:-1.55.0}"

if ! command -v node >/dev/null 2>&1; then
  echo "[error] node is required for playwright smoke checks"
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "[error] npx is required for playwright smoke checks"
  exit 1
fi

echo "[check] ensure playwright chromium browser is available"
npx --yes "playwright@${PLAYWRIGHT_VERSION}" install chromium >/dev/null

echo "[run] fdc3 playwright smoke rig"
npx --yes -p "playwright@${PLAYWRIGHT_VERSION}" node - "${TRADERX_URL}" "${TRADINGVIEW_URL}" "${TIMEOUT_MS}" <<'NODE'
const { chromium } = require("playwright");

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
      for (const listener of contextListeners) {
        if (!listener.contextType || listener.contextType === context?.type) {
          listener.handler(context);
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
    window.__fdc3ReceiveContext = receiveContext;
    window.__fdc3ReceiveIntent = receiveIntent;
    window.fdc3 = {
      broadcast: async (context) => {
        window.__fdc3CapturedBroadcasts.push(context);
      },
      raiseIntent: async (intent, context) => {
        window.__fdc3CapturedBroadcasts.push(context);
        receiveIntent(intent, context);
        return { intent };
      },
      addContextListener: async (contextType, handler) =>
        addContextListener(contextType, handler),
      addIntentListener: async (intent, handler) =>
        addIntentListener(intent, handler)
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

const getTradingViewSymbol = async (page) => {
  return page.evaluate(() => {
    const script = document.getElementById("tradingview-widget-script");
    if (!script) {
      return null;
    }
    const text = script.innerHTML || "";
    const match = text.match(/"symbol"\s*:\s*"([^"]+)"/i);
    return match ? match[1] : null;
  });
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
      const script = document.getElementById("tradingview-widget-script");
      if (!script) {
        return false;
      }
      const text = script.innerHTML || "";
      const match = text.match(/"symbol"\s*:\s*"([^"]+)"/i);
      if (!match) {
        return false;
      }
      const symbol = String(match[1] || "").toUpperCase();
      return symbol.includes(String(ticker || "").toUpperCase());
    }, selectedTicker, { timeout: 25000 });

    const resolvedSymbol = await getTradingViewSymbol(tradingViewPage);
    assert(typeof resolvedSymbol === "string" && resolvedSymbol.includes(":"), `expected exchange-qualified TradingView symbol, got ${resolvedSymbol}`);
    assert(resolvedSymbol.toUpperCase().includes(selectedTicker), `expected TradingView symbol to include ticker ${selectedTicker}, got ${resolvedSymbol}`);

    const inboundTicker = "MSFT";
    await traderxPage.evaluate((ticker) => {
      window.__fdc3ReceiveContext({
        type: "fdc3.instrument",
        id: { ticker }
      });
    }, inboundTicker);

    const filterBanner = traderxPage.locator(".sticky-filter-banner");
    await filterBanner.waitFor({ state: "visible", timeout: 15000 });
    const filterBannerText = (await filterBanner.innerText()).toUpperCase();
    assert(filterBannerText.includes("FILTERED BY"), `expected filter banner text, got ${filterBannerText}`);
    assert(filterBannerText.includes(inboundTicker), `expected inbound filter ticker ${inboundTicker}, got ${filterBannerText}`);

    const stickyPosition = await filterBanner.evaluate((el) => getComputedStyle(el).position);
    assert(stickyPosition === "sticky", `expected sticky filter banner, got position=${stickyPosition}`);

    await filterBanner.getByRole("button", { name: /clear filter/i }).click();
    await filterBanner.waitFor({ state: "hidden", timeout: 10000 });

    console.log(`[ok] outbound ticker broadcast captured: ${selectedTicker}`);
    console.log(`[ok] tradingview symbol resolved: ${resolvedSymbol}`);
    console.log(`[ok] inbound filter banner applied/cleared for ticker: ${inboundTicker}`);
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
