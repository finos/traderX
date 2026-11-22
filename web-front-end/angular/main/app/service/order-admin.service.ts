import { Injectable } from '@angular/core';
import { HttpClient, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { environment } from 'main/environments/environment';
import { OrderRecord, OrderCreateRequest } from '../model/order.model';
import { TradeFeedService } from './trade-feed.service';

@Injectable({
    providedIn: 'root'
})
export class OrderAdminService {
    private readonly ordersUrl = `${environment.orderMatcherUrl}/orders`;

    constructor(private http: HttpClient,
                private tradeFeed: TradeFeedService) {}

    getOpenOrders(accountId?: number): Observable<OrderRecord[]> {
        const query = accountId != null ? `?status=open&accountId=${accountId}` : '?status=open';
        return this.http.get<OrderRecord[]>(`${this.ordersUrl}${query}`).pipe(
            catchError(this.handleError)
        );
    }

    createOrder(order: OrderCreateRequest): Observable<OrderRecord> {
        return this.http.post<OrderRecord>(this.ordersUrl, order).pipe(
            catchError(this.handleError)
        );
    }

    cancelOrder(orderId: string): Observable<OrderRecord> {
        return this.http.post<OrderRecord>(`${this.ordersUrl}/${orderId}/cancel`, {}).pipe(
            catchError(this.handleError)
        );
    }

    forceFillOrder(orderId: string): Observable<OrderRecord> {
        return this.http.post<OrderRecord>(`${this.ordersUrl}/${orderId}/force-fill`, {}).pipe(
            catchError(this.handleError)
        );
    }

    subscribe(topic: string, callback: (order: OrderRecord) => void): () => void {
        return this.tradeFeed.subscribe(topic, callback);
    }

    private handleError(error: HttpErrorResponse) {
        console.error(error);
        return throwError(() => error);
    }
}
