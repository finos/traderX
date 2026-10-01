import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError, retry, tap } from 'rxjs/operators';
import { Trade, Position } from '../model/trade.model';
import { environment } from 'main/environments/environment';

@Injectable({
    providedIn: 'root'
})
export class PositionService {
    private tradesUrl = `${environment.positionsUrl}/trades/`;
    private positionsUrl = `${environment.positionsUrl}/positions/`;
    // Durable settlement registry served by the estate adapter (:8415) —
    // keyed by UETR, one-way Pndg → Acsc/Rjct enforced server-side. POST
    // publishes lifecycle transitions this browser observed; GET reconciles
    // rows in ANY browser / after refresh.
    private settlementsUrl = `${environment.positionsUrl}/trades/settlements/`;
    constructor(private http: HttpClient) { }

    getTrades(account_id: number): Observable<Trade[]> {
        return this.http.get<Trade[]>(this.tradesUrl + account_id ).pipe(
            catchError(this.handleError)
        );
    }

    getAllTrades(): Observable<Trade[]> {
        return this.http.get<Trade[]>(this.tradesUrl).pipe(
            catchError(this.handleError)
        );
    }

    getPositions(account_id: number): Observable<Position[]> {
        return this.http.get<Position[]>(this.positionsUrl + account_id ).pipe(
            catchError(this.handleError)
        );
    }

    getAllPositions(): Observable<Position[]> {
        return this.http.get<Position[]>(this.positionsUrl).pipe(
            catchError(this.handleError)
        );
    }

    getSettlements(): Observable<{ [uetr: string]: any }> {
        return this.http.get<{ [uetr: string]: any }>(this.settlementsUrl).pipe(
            catchError(this.handleError)
        );
    }

    postSettlements(entries: any[]): Observable<any> {
        return this.http.post<any>(this.settlementsUrl, { entries }).pipe(
            catchError(this.handleError)
        );
    }

    private handleError(error: HttpErrorResponse) {
        console.error(error);
        return throwError(() => error);
    }
}
