const fs = require('fs');
const path = require('path');
const express = require('express');
const { connect } = require('nats');
const yahooFinance = require('yahoo-finance2').default;

const PORT = Number(process.env.PRICE_PUBLISHER_PORT || '18100');
const NATS_URL = process.env.NATS_ADDRESS || `nats://${process.env.NATS_BROKER_HOST || 'localhost'}:4222`;
const BOOTSTRAP_MODE = (process.env.PRICE_BOOTSTRAP_MODE || 'snapshot').toLowerCase();
const TICKERS = (process.env.PRICE_TICKERS || 'AAPL,MSFT,AMZN,GOOGL,META,NVDA,TSLA,IBM,BAC,C')
  .split(',')
  .map((ticker) => ticker.trim().toUpperCase())
  .filter(Boolean);

const SNAPSHOT_PATH = path.join(__dirname, '..', 'data', 'snapshot-prices.json');

const app = express();
const state = {
  source: BOOTSTRAP_MODE,
  nats: null,
  prices: new Map()
};

function round3(value) {
  return Math.round(Number(value) * 1000) / 1000;
}

function clamp(value, low, high) {
  return Math.max(low, Math.min(high, value));
}

function loadSnapshot() {
  try {
    return JSON.parse(fs.readFileSync(SNAPSHOT_PATH, 'utf8'));
  } catch (err) {
    return {};
  }
}

function createFallbackQuote(ticker) {
  const basis = 100 + Math.random() * 50;
  return {
    ticker,
    openPrice: round3(basis),
    closePrice: round3(basis * (0.99 + Math.random() * 0.02)),
    price: round3(basis),
    source: 'fallback'
  };
}

function normalizeQuote(ticker, openPrice, closePrice, source) {
  const safeOpen = Number.isFinite(openPrice) ? Number(openPrice) : undefined;
  const safeClose = Number.isFinite(closePrice) ? Number(closePrice) : undefined;
  const open = round3(safeOpen ?? safeClose ?? 100);
  const close = round3(safeClose ?? safeOpen ?? open);
  return {
    ticker,
    openPrice: open,
    closePrice: close,
    price: close,
    source
  };
}

async function loadFromYahoo(ticker, snapshotEntry) {
  const quote = await yahooFinance.quote(ticker);
  const open = Number(quote.regularMarketOpen);
  const close = Number(quote.regularMarketPreviousClose ?? quote.regularMarketPrice);
  if (!Number.isFinite(open) && !Number.isFinite(close)) {
    throw new Error('yfinance quote missing open/close');
  }
  return normalizeQuote(ticker, open, close, 'yfinance');
}

async function bootstrapPrices() {
  const snapshot = loadSnapshot();
  for (const ticker of TICKERS) {
    const snapshotEntry = snapshot[ticker];
    if (BOOTSTRAP_MODE === 'yfinance') {
      try {
        const quote = await loadFromYahoo(ticker, snapshotEntry);
        state.prices.set(ticker, quote);
        continue;
      } catch (err) {
        // fall through to snapshot/fallback
      }
    }

    if (snapshotEntry) {
      state.prices.set(
        ticker,
        normalizeQuote(ticker, Number(snapshotEntry.openPrice), Number(snapshotEntry.closePrice), 'snapshot')
      );
    } else {
      state.prices.set(ticker, createFallbackQuote(ticker));
    }
  }
}

function updateTick(ticker) {
  const current = state.prices.get(ticker) || createFallbackQuote(ticker);
  const low = Math.min(current.openPrice, current.closePrice) * 0.9;
  const high = Math.max(current.openPrice, current.closePrice) * 1.1;
  const drift = current.price * (Math.random() * 0.01 - 0.005);
  const nextPrice = round3(clamp(current.price + drift, low, high));
  const next = {
    ...current,
    price: nextPrice
  };
  state.prices.set(ticker, next);
  return next;
}

function toPayload(quote) {
  return {
    ticker: quote.ticker,
    price: quote.price,
    openPrice: quote.openPrice,
    closePrice: quote.closePrice,
    asOf: new Date().toISOString(),
    source: quote.source
  };
}

function publishTick(quote) {
  if (!state.nats) {
    return;
  }
  const topic = `pricing.${quote.ticker}`;
  const envelope = {
    topic,
    payload: toPayload(quote),
    date: new Date().toISOString(),
    from: 'price-publisher',
    type: 'PriceTick'
  };
  state.nats.publish(topic, Buffer.from(JSON.stringify(envelope)));
}

function scheduleTickerLoop(ticker) {
  const loop = () => {
    const quote = updateTick(ticker);
    publishTick(quote);
    const delayMs = 1000 + Math.floor(Math.random() * 1000);
    setTimeout(loop, delayMs);
  };
  setTimeout(loop, 600);
}

function ensureTicker(ticker) {
  const normalized = String(ticker || '').trim().toUpperCase();
  if (!normalized) {
    return null;
  }
  if (!state.prices.has(normalized)) {
    state.prices.set(normalized, createFallbackQuote(normalized));
    scheduleTickerLoop(normalized);
  }
  return state.prices.get(normalized);
}

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    source: state.source,
    tickers: Array.from(state.prices.keys()).length
  });
});

app.get('/prices', (_req, res) => {
  const rows = Array.from(state.prices.values()).map((quote) => toPayload(quote));
  res.json({ prices: rows });
});

app.get('/prices/:ticker', (req, res) => {
  const quote = ensureTicker(req.params.ticker);
  if (!quote) {
    res.status(404).json({ message: 'ticker not found' });
    return;
  }
  res.json(toPayload(quote));
});

async function main() {
  await bootstrapPrices();
  state.nats = await connect({ servers: NATS_URL, maxReconnectAttempts: -1 });
  for (const ticker of state.prices.keys()) {
    scheduleTickerLoop(ticker);
  }
  app.listen(PORT, () => {
    console.log(`price-publisher listening on :${PORT}`);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
