export interface LineageStateEntry {
    id: string;
    title: string;
    sourceBranch: string;
    sourceBranchUrl: string;
    summary: string;
}

export interface StatusCheckDefinition {
    id: string;
    name: string;
    url: string;
    expectedStatuses: number[];
}

export interface RuntimeUiMetadata {
    runtimeStartedAtUtc: string;
    runtimeSource: string;
}

export interface StateUiMetadata {
    stateId: string;
    stateTitle: string;
    stateTrack: string;
    generatedAtUtc: string;
    sourceBranch: string;
    sourceBranchUrl: string;
    lineageLinkUrl: string;
    apiExplorerUrl: string;
    pubSubInspectorUrl: string;
    runtimeMetadataUrl: string;
    features: {
        statusPage: boolean;
        apiExplorer: boolean;
        pubSubInspector: boolean;
    };
    previousStates: LineageStateEntry[];
    statusChecks: StatusCheckDefinition[];
}
