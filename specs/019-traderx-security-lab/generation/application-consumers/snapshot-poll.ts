import { Observable } from 'rxjs';
import { SettlementSnapshot } from './settlement-snapshot';

/** One bounded in-flight snapshot; timer ticks coalesce instead of overlapping. */
export class SnapshotPoll<T> {
    private readonly snapshot: SettlementSnapshot<T>;
    private readonly timer: ReturnType<typeof setInterval>;
    constructor(fetch: () => Observable<T[]>, apply: (rows: T[]) => void) {
        this.snapshot = new SettlementSnapshot(fetch, apply);
        this.timer = setInterval(() => this.snapshot.refresh(), 2000);
        this.snapshot.refresh();
    }
    refresh(): void { this.snapshot.refresh(); }
    dispose(): void { clearInterval(this.timer); this.snapshot.dispose(); }
}
