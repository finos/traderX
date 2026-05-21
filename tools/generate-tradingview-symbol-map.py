#!/usr/bin/env python3
"""
Generate a TraderX ticker -> TradingView qualified symbol map.

Source strategy:
1. Parse Wikipedia S&P 500 constituents table symbol-link URLs.
2. Infer exchange prefix from URL patterns:
   - nyse.com/quote/XNYS:SYM -> NYSE:SYM
   - nasdaq.com/market-activity/stocks/sym -> NASDAQ:SYM
3. Merge manual overrides for supplemental non-S&P symbols used by TraderX.
4. Emit a TypeScript constant file for the web frontend bridge.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import pathlib
import re
import sys
import urllib.request
from html.parser import HTMLParser


WIKI_URL = "https://en.wikipedia.org/wiki/List_of_S%26P_500_companies"

MANUAL_OVERRIDES = {
    # Supplemental symbols in TraderX sample universe not guaranteed by S&P table.
    "MS": "NYSE:MS",
    "UBS": "NYSE:UBS",
    "C": "NYSE:C",
    "GS": "NYSE:GS",
    "DB": "NYSE:DB",
    "JPM": "NYSE:JPM",
    "COF": "NYSE:COF",
    "DFS": "NYSE:DFS",
    "FNMA": "OTCMKTS:FNMA",
    "FIS": "NYSE:FIS",
    "FNF": "NYSE:FNF",
    # Explicitly pin META for older FB->META transform in loader.
    "META": "NASDAQ:META",
}


class ConstituentsLinkParser(HTMLParser):
    """Extract first-column (symbol) text and its first anchor href from table#constituents."""

    def __init__(self) -> None:
        super().__init__()
        self.in_constituents = False
        self.in_tr = False
        self.td_index = -1
        self.capture_symbol_cell = False
        self.current_symbol_text = []
        self.current_symbol_href: str | None = None
        self.symbol_href: dict[str, str] = {}

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_map = dict(attrs)
        if tag == "table" and attrs_map.get("id") == "constituents":
            self.in_constituents = True
            return
        if not self.in_constituents:
            return

        if tag == "tr":
            self.in_tr = True
            self.td_index = -1
            self.capture_symbol_cell = False
            self.current_symbol_text = []
            self.current_symbol_href = None
            return

        if not self.in_tr:
            return

        if tag == "td":
            self.td_index += 1
            if self.td_index == 0:
                self.capture_symbol_cell = True
                self.current_symbol_text = []
                self.current_symbol_href = None
            return

        if tag == "a" and self.capture_symbol_cell and not self.current_symbol_href:
            href = attrs_map.get("href")
            if href:
                self.current_symbol_href = href

    def handle_endtag(self, tag: str) -> None:
        if tag == "table" and self.in_constituents:
            self.in_constituents = False
            return
        if not self.in_constituents:
            return

        if tag == "td" and self.capture_symbol_cell:
            symbol = "".join(self.current_symbol_text).strip().upper()
            if symbol and self.current_symbol_href:
                self.symbol_href[symbol] = self.current_symbol_href
            self.capture_symbol_cell = False
            return

        if tag == "tr":
            self.in_tr = False

    def handle_data(self, data: str) -> None:
        if self.capture_symbol_cell:
            self.current_symbol_text.append(data)


def fetch_html(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", "ignore")


def infer_tradingview_symbol(ticker: str, href: str | None) -> str | None:
    if not href:
        return None

    # NYSE pattern used on S&P table symbol links.
    nyse_match = re.search(r"/quote/XNYS:([A-Z.\-]+)$", href)
    if nyse_match:
        symbol = nyse_match.group(1).replace("-", ".").upper()
        return f"NYSE:{symbol}"

    # NASDAQ pattern used on S&P table symbol links.
    nasdaq_match = re.search(r"/market-activity/stocks/([a-z0-9.\-]+)$", href)
    if nasdaq_match:
        symbol = nasdaq_match.group(1).replace("-", ".").upper()
        return f"NASDAQ:{symbol}"

    # Some tables may use absolute URLs with same shapes.
    nyse_abs_match = re.search(r"nyse\.com/quote/XNYS:([A-Z.\-]+)$", href, flags=re.IGNORECASE)
    if nyse_abs_match:
        symbol = nyse_abs_match.group(1).replace("-", ".").upper()
        return f"NYSE:{symbol}"

    nasdaq_abs_match = re.search(r"nasdaq\.com/market-activity/stocks/([a-z0-9.\-]+)$", href, flags=re.IGNORECASE)
    if nasdaq_abs_match:
        symbol = nasdaq_abs_match.group(1).replace("-", ".").upper()
        return f"NASDAQ:{symbol}"

    return None


def load_csv_tickers(csv_path: pathlib.Path) -> set[str]:
    tickers: set[str] = set()
    with csv_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.reader(handle)
        next(reader, None)  # header
        for row in reader:
            if not row:
                continue
            raw = str(row[0]).strip().upper()
            if not raw:
                continue
            tickers.add("META" if raw == "FB" else raw)
    return tickers


def load_supplemental_tickers(loader_path: pathlib.Path) -> set[str]:
    text = loader_path.read_text(encoding="utf-8")
    return set(re.findall(r"ticker:\s*'([A-Z0-9.\-]+)'", text))


def build_map(tickers: set[str], symbol_href: dict[str, str]) -> dict[str, str]:
    out: dict[str, str] = {}
    unresolved: list[str] = []

    for ticker in sorted(tickers):
        if ticker in MANUAL_OVERRIDES:
            out[ticker] = MANUAL_OVERRIDES[ticker]
            continue

        inferred = infer_tradingview_symbol(ticker, symbol_href.get(ticker))
        if inferred:
            out[ticker] = inferred
        else:
            unresolved.append(ticker)

    if unresolved:
        print(
            "[warn] unresolved tickers (no wiki URL inference, no override): "
            + ", ".join(unresolved),
            file=sys.stderr,
        )

    return out


def render_ts(mapping: dict[str, str]) -> str:
    now = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    lines = [
        "// AUTO-GENERATED FILE. DO NOT EDIT MANUALLY.",
        f"// Generated by tools/generate-tradingview-symbol-map.py on {now}",
        f"// Source: {WIKI_URL}",
        "",
        "export const TRADINGVIEW_QUALIFIED_TICKER_BY_TRADERX_SYMBOL: { [ticker: string]: string } = {",
    ]
    for ticker in sorted(mapping):
        # Always quote object keys to keep dot-containing tickers valid TS keys (e.g. BRK.B).
        lines.append(f"    '{ticker}': '{mapping[ticker]}',")
    lines.append("};")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate TradingView symbol map TS file.")
    parser.add_argument("--csv", required=True, help="Path to s-and-p-500-companies.csv")
    parser.add_argument("--loader", required=True, help="Path to load-csv-data.ts for supplemental tickers")
    parser.add_argument("--output", required=True, help="Output path for TS map file")
    args = parser.parse_args()

    csv_path = pathlib.Path(args.csv).resolve()
    loader_path = pathlib.Path(args.loader).resolve()
    output_path = pathlib.Path(args.output).resolve()

    html = fetch_html(WIKI_URL)
    parser_obj = ConstituentsLinkParser()
    parser_obj.feed(html)

    csv_tickers = load_csv_tickers(csv_path)
    supplemental_tickers = load_supplemental_tickers(loader_path)
    target_tickers = csv_tickers | supplemental_tickers

    mapping = build_map(target_tickers, parser_obj.symbol_href)
    rendered = render_ts(mapping)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(rendered, encoding="utf-8")

    print(
        f"[ok] wrote {len(mapping)} mapped tickers to {output_path}",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
