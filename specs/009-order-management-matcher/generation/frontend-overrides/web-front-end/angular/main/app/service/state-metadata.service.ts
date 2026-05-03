import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { BehaviorSubject, Observable, of } from 'rxjs';
import { catchError, map } from 'rxjs/operators';
import { StateUiMetadata, StatusCheckDefinition } from '../model/state-ui-metadata.model';

const DEFAULT_STATUS_CHECKS: StatusCheckDefinition[] = [
    {
        id: 'account-service',
        name: 'Account Service',
        url: `${window.location.protocol}//${window.location.hostname}:18088/account/22214`,
        expectedStatuses: [200]
    },
    {
        id: 'reference-data',
        name: 'Reference Data',
        url: `${window.location.protocol}//${window.location.hostname}:18085/stocks`,
        expectedStatuses: [200]
    },
    {
        id: 'position-service',
        name: 'Position Service',
        url: `${window.location.protocol}//${window.location.hostname}:18090/health/alive`,
        expectedStatuses: [200]
    },
    {
        id: 'trade-service',
        name: 'Trade Service',
        url: `${window.location.protocol}//${window.location.hostname}:18092/v3/api-docs`,
        expectedStatuses: [200]
    },
    {
        id: 'people-service',
        name: 'People Service',
        url: `${window.location.protocol}//${window.location.hostname}:18089/People/GetPerson?LogonId=user01`,
        expectedStatuses: [200]
    },
    {
        id: 'trade-feed',
        name: 'Trade Feed',
        url: `${window.location.protocol}//${window.location.hostname}:18086/socket.io/?EIO=4&transport=polling`,
        expectedStatuses: [200]
    }
];

const DEFAULT_METADATA: StateUiMetadata = {
    stateId: '001-baseline-uncontainerized-parity',
    stateTitle: 'Simple App - Base Uncontainerized App',
    stateTrack: 'prelude',
    generatedAtUtc: '',
    sourceBranch: 'code/generated-state-001-baseline-uncontainerized-parity',
    sourceBranchUrl: '',
    lineageLinkUrl: '',
    apiExplorerUrl: '/api/docs',
    pubSubInspectorUrl: '/api/docs/pubsub-inspector.html',
    features: {
        statusPage: false,
        apiExplorer: false,
        pubSubInspector: false
    },
    previousStates: [],
    statusChecks: DEFAULT_STATUS_CHECKS
};

@Injectable({
    providedIn: 'root'
})
export class StateMetadataService {
    private readonly metadataSubject = new BehaviorSubject<StateUiMetadata>(DEFAULT_METADATA);
    readonly metadata$: Observable<StateUiMetadata> = this.metadataSubject.asObservable();

    constructor(private readonly httpClient: HttpClient) {
        this.refresh();
    }

    refresh(): void {
        this.httpClient.get<StateUiMetadata>('assets/state-ui.json').pipe(
            map((metadata) => this.normalize(metadata)),
            catchError((error) => {
                console.warn('[state-metadata] using defaults due to load error', error);
                return of(DEFAULT_METADATA);
            })
        ).subscribe((metadata) => this.metadataSubject.next(metadata));
    }

    snapshot(): StateUiMetadata {
        return this.metadataSubject.value;
    }

    private normalize(metadata: StateUiMetadata): StateUiMetadata {
        const statusChecks = Array.isArray(metadata?.statusChecks) && metadata.statusChecks.length > 0
            ? metadata.statusChecks
            : DEFAULT_STATUS_CHECKS;

        return {
            ...DEFAULT_METADATA,
            ...metadata,
            features: {
                ...DEFAULT_METADATA.features,
                ...(metadata?.features ?? {})
            },
            previousStates: Array.isArray(metadata?.previousStates) ? metadata.previousStates : [],
            statusChecks
        };
    }
}
