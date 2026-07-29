import { CommonModule } from '@angular/common';
import { Component, OnDestroy, OnInit } from '@angular/core';
import { Subscription } from 'rxjs';
import { StateUiMetadata, StatusCheckDefinition } from '../model/state-ui-metadata.model';
import { StateMetadataService } from '../service/state-metadata.service';

interface ServiceStatusRow {
    id: string;
    name: string;
    url: string;
    expectedStatuses: number[];
    lastCheckedUtc: string;
    latencyMs: number | null;
    httpStatus: number | null;
    available: boolean;
    upSinceUtc: string;
    error: string;
}

@Component({
    standalone: true,
    selector: 'app-status',
    imports: [CommonModule],
    templateUrl: './status.component.html',
    styleUrls: ['./status.component.scss']
})
export class StatusComponent implements OnInit, OnDestroy {
    metadata: StateUiMetadata;
    statusRows: ServiceStatusRow[] = [];
    checking = false;
    lastRefreshUtc = '';

    private metadataSub: Subscription | null = null;
    private intervalId: ReturnType<typeof setInterval> | null = null;

    constructor(private readonly stateMetadataService: StateMetadataService) {
        this.metadata = this.stateMetadataService.snapshot();
    }

    ngOnInit(): void {
        this.metadataSub = this.stateMetadataService.metadata$.subscribe((metadata) => {
            this.metadata = metadata;
            this.statusRows = this.buildRows(metadata.statusChecks);
            if (metadata.features.statusPage) {
                this.refreshAll();
            }
            this.resetInterval();
        });
    }

    ngOnDestroy(): void {
        this.metadataSub?.unsubscribe();
        if (this.intervalId) {
            clearInterval(this.intervalId);
        }
    }

    async refreshAll(): Promise<void> {
        this.checking = true;
        await Promise.all(this.statusRows.map((row) => this.refreshOne(row)));
        this.lastRefreshUtc = new Date().toISOString();
        this.checking = false;
    }

    statusClass(row: ServiceStatusRow): string {
        return row.available ? 'status-up' : 'status-down';
    }

    toRelativeTime(value: string): string {
        if (!value) {
            return '-';
        }
        const ts = new Date(value);
        if (Number.isNaN(ts.getTime())) {
            return value;
        }
        const diffMs = Date.now() - ts.getTime();
        const diffSec = Math.max(0, Math.floor(diffMs / 1000));
        if (diffSec < 60) {
            return `${diffSec}s ago`;
        }
        const diffMin = Math.floor(diffSec / 60);
        if (diffMin < 60) {
            return `${diffMin}m ago`;
        }
        const diffHr = Math.floor(diffMin / 60);
        return `${diffHr}h ago`;
    }

    private resetInterval(): void {
        if (this.intervalId) {
            clearInterval(this.intervalId);
            this.intervalId = null;
        }
        if (!this.metadata.features.statusPage) {
            return;
        }
        this.intervalId = setInterval(() => {
            this.refreshAll().catch((error) => {
                console.warn('[status-page] refresh failed', error);
            });
        }, 30000);
    }

    private buildRows(statusChecks: StatusCheckDefinition[]): ServiceStatusRow[] {
        return statusChecks.map((check) => ({
            id: check.id,
            name: check.name,
            url: check.url,
            expectedStatuses: check.expectedStatuses,
            lastCheckedUtc: '',
            latencyMs: null,
            httpStatus: null,
            available: false,
            upSinceUtc: '',
            error: ''
        }));
    }

    private async refreshOne(row: ServiceStatusRow): Promise<void> {
        const started = Date.now();
        const timeoutMs = 6000;
        const controller = new AbortController();
        const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

        let httpStatus: number | null = null;
        let available = false;
        let error = '';

        try {
            const response = await fetch(row.url, {
                method: 'GET',
                cache: 'no-store',
                signal: controller.signal
            });
            httpStatus = response.status;
            available = row.expectedStatuses.includes(response.status);
        } catch (requestError) {
            error = requestError instanceof Error ? requestError.message : String(requestError);
            available = false;
        } finally {
            clearTimeout(timeoutId);
        }

        const nowUtc = new Date().toISOString();
        const latencyMs = Date.now() - started;
        if (available && !row.upSinceUtc) {
            row.upSinceUtc = nowUtc;
        }
        if (!available) {
            row.upSinceUtc = '';
        }

        row.httpStatus = httpStatus;
        row.available = available;
        row.lastCheckedUtc = nowUtc;
        row.latencyMs = latencyMs;
        row.error = error;
    }
}
