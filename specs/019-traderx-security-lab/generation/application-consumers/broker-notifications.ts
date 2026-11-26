import { Injectable, OnDestroy } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Subject, Subscription, timeout } from 'rxjs';
import { BrowserSession } from './browser-session';
import { settlementMatches } from './settlement-snapshot';

export type FeedState = 'connecting' | 'connected' | 'disconnected';
export type Notification = {topic:string; accountId:number; eventId:string; executionId:string; eventKind:string; eventSequence:number};

export function notificationMatches(value: any): value is Notification {
    if (!value || typeof value !== 'object' || Array.isArray(value) ||
        Object.keys(value).sort().join(',') !== 'accountId,eventId,eventKind,eventSequence,executionId,topic') return false;
    return !!settlementMatches(value.topic, {eventId:value.eventId, executionId:value.executionId,
        eventKind:value.eventKind, eventSequence:value.eventSequence, payload:{accountId:value.accountId}});
}

@Injectable({providedIn:'root'})
export class BrokerNotifications implements OnDestroy {
    private readonly state = new BehaviorSubject<FeedState>('disconnected');
    private readonly received = new Subject<Notification>();
    readonly connectionState$ = this.state.asObservable();
    readonly events$ = this.received.asObservable();
    private cursor?: string;
    private pending?: Subscription;
    private timer?: ReturnType<typeof setTimeout>;
    private readonly sessionState: Subscription;
    private stopped = true;
    private retry = 1000;

    constructor(private http: HttpClient, private session: BrowserSession) {
        this.sessionState = session.state$.subscribe(state => {
            if (state === 'signed-in') this.start(); else this.stop();
        });
    }

    start(): void {
        if (!this.stopped || !this.session.credentials()) return;
        this.stopped = false; this.retry = 1000; this.state.next('connecting'); this.poll();
    }

    private stop(): void {
        this.stopped = true; this.pending?.unsubscribe(); this.pending = undefined;
        clearTimeout(this.timer); this.timer = undefined; this.cursor = undefined;
        this.state.next('disconnected');
    }

    private schedule(delay: number): void {
        if (!this.stopped) this.timer = setTimeout(() => { this.timer = undefined; this.poll(); }, delay);
    }

    private poll(): void {
        if (this.stopped || !this.session.credentials()) { this.stop(); return; }
        const path = this.cursor ? '/events?after=' + encodeURIComponent(this.cursor) : '/events';
        this.pending = this.http.get<any>(path).pipe(timeout(5000)).subscribe({
            next: page => {
                if (!page || Object.keys(page).sort().join(',') !== 'cursor,events,reset' ||
                    typeof page.cursor !== 'string' || !/^[0-9a-f]{32}:(0|[1-9][0-9]{0,15})$/.test(page.cursor) ||
                    typeof page.reset !== 'boolean' || !Array.isArray(page.events) || page.events.length > 64 ||
                    (page.reset && page.events.length !== 0) || !page.events.every(notificationMatches)) {
                    this.failed(); return;
                }
                this.cursor = page.cursor; this.retry = 1000;
                if (page.reset || this.state.value !== 'connected') {
                    this.state.next('disconnected'); this.state.next('connected');
                }
                for (const event of page.events) this.received.next(event);
                this.schedule(1000);
            },
            error: error => {
                if (error.status === 401 || error.status === 403) { this.session.clear(); this.stop(); }
                else this.failed();
            }
        });
    }

    private failed(): void {
        this.cursor = undefined; this.state.next('disconnected');
        this.schedule(this.retry); this.retry = Math.min(this.retry * 2, 5000);
    }

    ngOnDestroy(): void { this.stop(); this.sessionState.unsubscribe(); }
}
