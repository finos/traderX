import { ComponentFixture, TestBed } from '@angular/core/testing';
import { HttpClientTestingModule } from '@angular/common/http/testing';
import { RouterTestingModule } from '@angular/router/testing';
import { BehaviorSubject } from 'rxjs';

import { HeaderComponent } from './header.component';
import { StateUiMetadata } from '../model/state-ui-metadata.model';
import { StateMetadataService } from '../service/state-metadata.service';
import { MessageBusConnectionState, TradeFeedService } from '../service/trade-feed.service';

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
  statusChecks: []
};

describe('HeaderComponent', () => {
  let component: HeaderComponent;
  let fixture: ComponentFixture<HeaderComponent>;
  let metadata$: BehaviorSubject<StateUiMetadata>;
  let connectionState$: BehaviorSubject<MessageBusConnectionState>;

  beforeEach(async () => {
    metadata$ = new BehaviorSubject<StateUiMetadata>(DEFAULT_METADATA);
    connectionState$ = new BehaviorSubject<MessageBusConnectionState>('connected');

    await TestBed.configureTestingModule({
      declarations: [ HeaderComponent ],
      imports: [HttpClientTestingModule, RouterTestingModule],
      providers: [
        {
          provide: StateMetadataService,
          useValue: {
            metadata$: metadata$.asObservable()
          }
        },
        {
          provide: TradeFeedService,
          useValue: {
            connectionState$: connectionState$.asObservable()
          }
        }
      ]
    })
    .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(HeaderComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
