import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { PriceTick } from '../model/trade.model';
import { Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';

@Injectable({
  providedIn: 'root'
})
export class PriceSnapshotService {
  private readonly baseUrl = '/price-publisher';

  constructor(private http: HttpClient) {}

  getPrice(ticker: string): Observable<PriceTick | null> {
    const normalizedTicker = this.normalizeTicker(ticker);
    if (!normalizedTicker) {
      return of(null);
    }
    return this.http.get<PriceTick>(`${this.baseUrl}/prices/${encodeURIComponent(normalizedTicker)}`).pipe(
      map((snapshot) => this.normalizeSnapshot(snapshot, normalizedTicker)),
      catchError(() => of(null))
    );
  }

  getPrices(tickers: string[]): Observable<PriceTick[]> {
    const normalizedTickers = Array.from(new Set((tickers || [])
      .map((ticker) => this.normalizeTicker(ticker))
      .filter((ticker): ticker is string => !!ticker)));

    if (normalizedTickers.length === 0) {
      return of([]);
    }

    const tickerFilter = new Set(normalizedTickers);
    return this.http.get<PriceTick[]>(`${this.baseUrl}/prices`).pipe(
      map((snapshots) => (snapshots || [])
        .map((snapshot) => this.normalizeSnapshot(snapshot))
        .filter((snapshot): snapshot is PriceTick => !!snapshot && tickerFilter.has(snapshot.ticker))),
      catchError(() => of([]))
    );
  }

  private normalizeTicker(ticker: string | null | undefined): string | null {
    const normalized = String(ticker || '').trim().toUpperCase();
    return normalized || null;
  }

  private normalizeSnapshot(snapshot: PriceTick | null | undefined, fallbackTicker?: string): PriceTick | null {
    if (!snapshot || typeof snapshot !== 'object') {
      return null;
    }

    const normalizedTicker = this.normalizeTicker(snapshot.ticker) || this.normalizeTicker(fallbackTicker || '');
    const normalizedPrice = Number((snapshot as any).price);
    const normalizedOpen = Number((snapshot as any).openPrice ?? normalizedPrice);
    const normalizedClose = Number((snapshot as any).closePrice ?? normalizedPrice);

    if (!normalizedTicker || !Number.isFinite(normalizedPrice)) {
      return null;
    }

    return {
      ticker: normalizedTicker,
      price: normalizedPrice,
      openPrice: Number.isFinite(normalizedOpen) ? normalizedOpen : normalizedPrice,
      closePrice: Number.isFinite(normalizedClose) ? normalizedClose : normalizedPrice,
      asOf: typeof (snapshot as any).asOf === 'string' ? (snapshot as any).asOf : '',
      source: typeof (snapshot as any).source === 'string' ? (snapshot as any).source : 'snapshot'
    };
  }
}
