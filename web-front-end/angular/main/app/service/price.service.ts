import { Injectable } from '@angular/core';
import { Stock } from '../model/symbol.model';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry } from 'rxjs/operators';
import { Trade, StockPrice, Position } from '../model/trade.model';
import { environment } from 'main/environments/environment';

@Injectable({
    providedIn: 'root'
})
export class PriceService {
    private stocksUrl = `${environment.referenceServiceUrl}/stocks`;
    private priceUrl = `${environment.referenceServiceUrl}/price`;
    private pricesUrl = `${environment.referenceServiceUrl}/prices`;
    private tradesUrl = `${environment.referenceServiceUrl}/trades`;
    private positionsUrl = `${environment.referenceServiceUrl}/positions`;
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

    getAccountPrices(accountId: number): Observable<StockPrice[]> {
        return this.http.get<StockPrice[]>(`${this.pricesUrl}/${accountId}`).pipe(
            retry(2),
            catchError(this.handleError)
        );
    }

    getTrades(account_id: number): Observable<Trade[]> {
      return this.http.get<Trade[]>(`${this.tradesUrl}/${account_id}`).pipe(
        retry(2),
        catchError(this.handleError)
      );
    }

    getPositions(account_id: number): Observable<Position[]> {
      return this.http.get<Position[]>(`${this.positionsUrl}/${account_id}`).pipe(
        retry(2),
        catchError(this.handleError)
      );
    }

    private handleError(error: HttpErrorResponse) {
        console.error(error);
        return throwError(() => error);
    }
}
