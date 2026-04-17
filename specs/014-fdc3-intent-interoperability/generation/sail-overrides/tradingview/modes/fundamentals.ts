import { TradingViewMode } from "../common"
import { resolveTradingViewSymbolFromContext } from "./symbol-compat"

/* eslint-disable  @typescript-eslint/no-explicit-any */

const ensureFundamentalsSymbol = (symbol: string | undefined): string | undefined => {
  if (!symbol) return undefined
  const normalized = symbol.trim().toUpperCase()
  return normalized.includes(":") ? normalized : undefined
}

export const fundamentalsMode: TradingViewMode = {
  name: "fundamentals",
  script:
    "https://s3.tradingview.com/external-embedding/embed-widget-financials.js",
  innerHTML: (state: object) => `{
                    "isTransparent": false,
                    "largeChartUrl": "",
                    "displayMode": "regular",
                    "width": "100%",
                    "height": "100%",
                    "colorTheme": "light",
                    "symbol": "${state}",
                    "locale": "en"
                }`,
  initialState: "NASDAQ:TSLA",
  intents: [
    {
      name: "ViewInstrument",
      function: (context: any) => {
        return ensureFundamentalsSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
    {
      name: "ViewChart",
      function: (context: any) => {
        return ensureFundamentalsSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
  ],
  listeners: [
    {
      name: "fdc3.instrument",
      function: (context: any) => {
        return ensureFundamentalsSymbol(resolveTradingViewSymbolFromContext(context))
      },
    },
  ],
}
