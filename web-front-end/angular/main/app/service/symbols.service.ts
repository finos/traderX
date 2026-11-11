import { Injectable } from '@angular/core';
import { Stock } from '../model/symbol.model';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry } from 'rxjs/operators';
import { TradeTicket } from '../model/trade.model';
import { environment } from 'main/environments/environment';

@Injectable({
    providedIn: 'root'
})
export class SymbolService {
    private stocksUrl = `${environment.refrenceDataUrl}/stocks`;
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

    private handleError(error: HttpErrorResponse) {
        console.error(error);
        return throwError(() => error);
    }
}
