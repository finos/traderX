import { AllCommunityModule, ModuleRegistry, provideGlobalGridOptions } from 'ag-grid-community';

ModuleRegistry.registerModules([AllCommunityModule]);
provideGlobalGridOptions({ theme: 'legacy' });
