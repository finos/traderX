import { Injectable, inject } from '@angular/core';
import { HttpBackend, HttpClient, HttpErrorResponse, HttpInterceptorFn } from '@angular/common/http';
import { BehaviorSubject, Subject, Subscription, catchError, takeUntil, throwError, timeout } from 'rxjs';

type SessionState = 'checking' | 'signed-in' | 'signed-out';

@Injectable({providedIn: 'root'})
export class BrowserSession {
    private readonly client: HttpClient;
    private readonly status = new BehaviorSubject<SessionState>('checking');
    private readonly ended = new Subject<void>();
    readonly state$ = this.status.asObservable();
    readonly ended$ = this.ended.asObservable();
    subject = '';
    private csrf = '';
    private until = 0;
    private expiry?: ReturnType<typeof setTimeout>;
    private loading?: Subscription;

    constructor(backend: HttpBackend) { this.client = new HttpClient(backend); }

    clear(): void {
        this.loading?.unsubscribe(); this.loading = undefined;
        clearTimeout(this.expiry); this.expiry = undefined;
        this.subject = ''; this.csrf = ''; this.until = 0;
        this.status.next('signed-out'); this.ended.next();
    }

    refresh(): void {
        this.clear(); this.status.next('checking');
        this.loading = this.client.get<any>('/session').pipe(timeout(5000)).subscribe({
            next: value => {
                const remaining = value?.expiresAt * 1000 - Date.now();
                if (typeof value?.subject !== 'string' || !value.subject ||
                    typeof value?.csrf !== 'string' || !/^[A-Za-z0-9_-]{43}$/.test(value.csrf) ||
                    !Number.isFinite(value?.expiresAt) || remaining <= 0 || remaining > 301000) {
                    this.clear(); return;
                }
                this.subject = value.subject; this.csrf = value.csrf;
                this.until = value.expiresAt * 1000;
                this.expiry = setTimeout(() => this.clear(), remaining);
                this.status.next('signed-in');
            },
            error: () => this.clear()
        });
    }

    credentials(): string | null {
        if (this.status.value !== 'signed-in' || Date.now() >= this.until) {
            if (this.status.value === 'signed-in') this.clear();
            return null;
        }
        return this.csrf;
    }

    logout(): void {
        const csrf = this.credentials();
        this.clear();
        if (csrf) this.client.post('/logout', null, {headers: {'X-CSRF-Token': csrf}})
            .pipe(timeout(5000)).subscribe({error: () => { /* Local UI remains signed out. */ }});
    }
}

export const browserSessionInterceptor: HttpInterceptorFn = (request, next) => {
    const url = new URL(request.url, window.location.origin);
    const application = /^\/(?:api\/)?(?:account-service|position-service|order-matcher|trade-service)(?:\/|$)/.test(url.pathname);
    if (!application) return next(request);
    const session = inject(BrowserSession);
    // No auth material goes to an external URL, even if it resembles an API path.
    if (url.origin !== window.location.origin)
        return throwError(() => new HttpErrorResponse({status: 403, statusText: 'External API refused'}));
    const csrf = session.credentials();
    if (!csrf) return throwError(() => new HttpErrorResponse({status: 401, statusText: 'Sign in required'}));
    const path = url.pathname.startsWith('/api/') ? url.pathname : '/api' + url.pathname;
    let headers = request.headers.delete('Authorization').delete('X-CSRF-Token')
        .delete('X-Role').delete('X-Account-Id');
    if (!['GET', 'HEAD', 'OPTIONS'].includes(request.method)) headers = headers.set('X-CSRF-Token', csrf);
    return next(request.clone({url: path + url.search, headers})).pipe(
        takeUntil(session.ended$),
        catchError(error => {
            if (error.status === 401) session.clear();
            return throwError(() => error);
        })
    );
};
