import { TradingViewMode } from "../common"
import { resolveTradingViewSymbolFromContext } from "./symbol-compat"

/* eslint-disable  @typescript-eslint/no-explicit-any */

const ensureSymbolInfoSymbol = (symbol: string | undefined): string | undefined => {
  if (!symbol) return undefined
  const normalized = symbol.trim().toUpperCase()
  return normalized.includes(":") ? normalized : undefined
}

export const symbolInfoMode: TradingViewMode = {
  name: "symbol-info",
  script:
    "https://s3.tradingview.com/external-embedding/embed-widget-symbol-info.js",
  innerHTML: (state: object) => `{
          "autosize": true,
          "symbol": "${state}",
          "interval": "D",
          "timezone": "Etc/UTC",
          "theme": "light",
          "style": "1",
          "locale": "en",
          "allow_symbol_change": false,
          "calendar": false,
          "support_host": "https://www.tradingview.com"
        }`,
  initialState: "NASDAQ:TSLA",
  intents: [
    {
      name: "ViewInstrument",
      function: (context: any) => {
        return ensureSymbolInfoSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
    {
      name: "ViewChart",
      function: (context: any) => {
        return ensureSymbolInfoSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
  ],
  listeners: [
    {
      name: "fdc3.instrument",
      function: (context: any) => {
        return ensureSymbolInfoSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
  ],
}
