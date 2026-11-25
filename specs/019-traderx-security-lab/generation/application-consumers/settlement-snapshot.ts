import { Observable, Subscription, take, timeout } from 'rxjs';

/** Browser invalidation only: no durable acknowledgment or business mutation. */
export class SettlementSnapshot<T> {
    private active = true;
    private dirty = false;
    private busy = false;
    private timer: ReturnType<typeof setTimeout> | undefined;
    private request: Subscription | undefined;
    constructor(private fetch: () => Observable<T[]>, private apply: (rows: T[]) => void) {}
    refresh(): void {
        if (!this.active) return;
        this.dirty = true;
        if (this.busy || this.timer !== undefined) return;
        this.timer = setTimeout(() => { this.timer = undefined; this.run(); }, 100);
    }
    private run(): void {
        if (!this.active) return;
        this.dirty = false;
        this.busy = true;
        const finish = () => {
            this.busy = false;
            if (this.dirty) this.refresh();
        };
        try {
            this.request = this.fetch().pipe(take(1), timeout(5000)).subscribe({
                next: rows => { if (this.active) this.apply(rows ?? []); },
                error: () => { if (this.active) this.apply([]); finish(); },
                complete: finish
            });
        } catch (_) {
            if (this.active) this.apply([]);
            finish();
        }
    }
    dispose(): void {
        this.active = false;
        clearTimeout(this.timer);
        this.request?.unsubscribe();
    }
}

export function settlementMatches(topic: string, message: any): boolean {
    const match = /^\/accounts\/([1-9][0-9]*)\/(trades|positions)$/.exec(topic);
    if (!match || !message || typeof message !== 'object' || Array.isArray(message)) return false;
    if (Object.keys(message).sort().join(',') !== 'eventId,eventKind,eventSequence,executionId,payload') return false;
    const account = Number(match[1]);
    const kind = match[2] === 'trades' ? 'trade.settled' : 'position.updated';
    const suffix = match[2] === 'trades' ? 'trade' : 'position';
    return Number.isSafeInteger(account) && Number.isSafeInteger(message.eventSequence) && message.eventSequence > 0
        && typeof message.executionId === 'string'
        && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(message.executionId)
        && message.eventId === `${message.executionId}:${suffix}` && message.eventKind === kind
        && !!message.payload && typeof message.payload === 'object' && !Array.isArray(message.payload)
        && message.payload.accountId === account;
}
