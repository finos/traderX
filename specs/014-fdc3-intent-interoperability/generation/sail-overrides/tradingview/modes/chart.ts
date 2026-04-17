import { TradingViewMode } from "../common"
import { resolveTradingViewSymbolFromContext } from "./symbol-compat"

/* eslint-disable  @typescript-eslint/no-explicit-any */

const ensureChartSymbol = (symbol: string | undefined): string | undefined => {
  if (!symbol) return undefined
  const normalized = symbol.trim().toUpperCase()
  return normalized.includes(":") ? normalized : undefined
}

export const chartMode: TradingViewMode = {
  name: "chart",
  script:
    "https://s3.tradingview.com/external-embedding/embed-widget-advanced-chart.js",
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
      name: "ViewChart",
      function: (context: any) => {
        return ensureChartSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
  ],
  listeners: [
    {
      name: "fdc3.instrument",
      function: (context: any) => {
        return ensureChartSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
  ],
}
