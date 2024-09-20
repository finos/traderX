import { Injectable } from '@angular/core';
import { Stock } from '../model/symbol.model';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry } from 'rxjs/operators';
import { Trade, StockPrice, Position, TradePointInTime, TradeInterval } from '../model/trade.model';
import { environment } from 'main/environments/environment';

@Injectable({
    providedIn: 'root'
})
export class PriceService {
    private stocksUrl = `${environment.referenceServiceUrl}/stocks`;
    private priceUrl = `${environment.referenceServiceUrl}/price`;
    private pricesUrl = `${environment.referenceServiceUrl}/prices`;
    private tradesUrl = `${environment.referenceServiceUrl}/trades`;
    private pointsInTimeUrl = `${environment.referenceServiceUrl}/points-in-time`;
    private positionsUrl = `${environment.referenceServiceUrl}/positions`;
    private tradeIntervalUrl = `${environment.referenceServiceUrl}/trade-intervals`;

    constructor(private http: HttpClient) { }

    getStocks(): Observable<Stock[]> {
        return this.http.get<Stock[]>(this.stocksUrl).pipe(
            retry(2),
            catchError(this.handleError)
        );
    }

    getPrice(ticker: string): Observable<StockPrice> {
        return this.http.get<StockPrice>(`${this.priceUrl}/${ticker}`).pipe(
            retry(2),
            catchError(this.handleError)
        );
    }

    getAccountPrices(accountId: number, forDate?: Date): Observable<StockPrice[]> {
        const url = (forDate !== undefined) ?
          `${this.pricesUrl}/${accountId}/${forDate.toISOString()}` :
          `${this.pricesUrl}/${accountId}`;
        return this.http.get<StockPrice[]>(url).pipe(
            retry(2),
            catchError(this.handleError)
        );
    }

    getTrades(accountId: number, interval?: TradeInterval): Observable<Trade[]> {
      const url = (interval !== undefined && interval.start !== undefined)
                ? `${this.tradesUrl}/${accountId}/${interval.start}`
                : `${this.tradesUrl}/${accountId}`;
      console.log(`getTrades ${interval}`, url);
      return this.http.get<Trade[]>(url).pipe(
        retry(2),
        catchError(this.handleError)
      );
    }

    getPositions(accountId: number, interval?: TradeInterval): Observable<Position[]> {
      const url = (interval && interval.start !== undefined)
                ? `${this.positionsUrl}/${accountId}/${interval.start}`
                :  `${this.positionsUrl}/${accountId}`;
      console.log(`getPositions ${url}`);
      return this.http.get<Position[]>(url).pipe(
        retry(2),
        catchError(this.handleError)
      );
    }

    getPointsInTime(accountId: number): Observable<string[]> {
      return this.http.get<string[]>(`${this.pointsInTimeUrl}/${accountId}`).pipe(
        retry(2),
        catchError(this.handleError)
      );
    }

    getTradeIntervals(accountId: number): Observable<TradeInterval[]> {
      return this.http.get<TradeInterval[]>(`${this.tradeIntervalUrl}/${accountId}`).pipe(
        retry(2),
        catchError(this.handleError)
      );
    }

    private handleError(error: HttpErrorResponse) {
        console.error(error);
        return throwError(() => error);
    }
}
