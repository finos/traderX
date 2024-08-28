import { Injectable } from '@angular/core';
import { Stock } from '../model/symbol.model';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry } from 'rxjs/operators';
import { TradeTicket, StockPrice } from '../model/trade.model';
import { environment } from 'main/environments/environment';

@Injectable({
    providedIn: 'root'
})
export class SymbolService {
    private stocksUrl = `${environment.referenceServiceUrl}/stocks`;
    private priceUrl = `${environment.referenceServiceUrl}/price/`;
    private createTicketUrl = `${environment.tradesUrl}`;
    constructor(private http: HttpClient) { }

    getStocks(): Observable<Stock[]> {
        return this.http.get<Stock[]>(this.stocksUrl).pipe(
            retry(2),
            catchError(this.handleError)
        );
    }

    createTicket(ticket: TradeTicket): Observable<any> {
        return this.http.post(this.createTicketUrl, ticket).pipe(
            catchError(this.handleError)
        );
    }

    getPrice(ticker: string): Observable<StockPrice> {
        return this.http.get<StockPrice>(`${this.priceUrl}/${ticker}`).pipe(
            retry(2),
            catchError(this.handleError)
        );
    }

    private handleError(error: HttpErrorResponse) {
        console.error(error);
        return throwError(() => error);
    }
}
