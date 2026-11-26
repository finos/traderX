import { Injectable, OnDestroy } from '@angular/core';
import { Subscription } from 'rxjs';
import { BrokerNotifications, FeedState, Notification, notificationMatches } from './broker-notifications';

export type MessageBusConnectionState = FeedState;

@Injectable({providedIn:'root'})
export class TradeFeedService implements OnDestroy {
    private nextSid = 1;
    private readonly subscriptions = new Map<number, {topic:string; callback:(...args:any[])=>void; settlement:boolean}>();
    public readonly connectionState$;
    private readonly events: Subscription;

    constructor(private notifications: BrokerNotifications) {
        this.connectionState$ = notifications.connectionState$;
        this.events = notifications.events$.subscribe(event => this.dispatchNotification(event));
    }

    private dispatchNotification(event: Notification): void {
        if (!notificationMatches(event)) return;
        for (const record of this.subscriptions.values())
            if (record.settlement && record.topic === event.topic) record.callback();
    }

    public subscribeSettlement(topic: string, callback: () => void): () => void {
        if (!/^\/accounts\/[1-9][0-9]*\/(trades|positions)$/.test(topic)) throw new Error('Explicit settlement account required');
        const sid=this.nextSid++;
        this.subscriptions.set(sid,{topic,callback,settlement:true});
        this.notifications.start();
        return () => this.subscriptions.delete(sid);
    }

    public subscribe(topic: string, callback: (...args:any[]) => void): () => void {
        // Pricing and legacy order payloads require their own explicit contract.
        // They never fall back to the anonymous C3 WebSocket.
        const sid=this.nextSid++;
        this.subscriptions.set(sid,{topic,callback,settlement:false});
        return () => this.subscriptions.delete(sid);
    }

    public unSubscribe(topic: string, callback: (...args:any[]) => void): void {
        for (const [sid,record] of this.subscriptions)
            if (record.topic===topic && record.callback===callback) this.subscriptions.delete(sid);
    }

    ngOnDestroy(): void { this.events.unsubscribe(); this.subscriptions.clear(); }
}
