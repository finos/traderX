import { ComponentFixture, TestBed } from '@angular/core/testing';
import { BehaviorSubject } from 'rxjs';
import { NO_ERRORS_SCHEMA } from '@angular/core';

import { HeaderComponent } from './header.component';
import { StateMetadataService } from '../service/state-metadata.service';
import { MessageBusConnectionState, TradeFeedService } from '../service/trade-feed.service';

describe('HeaderComponent', () => {
  let component: HeaderComponent;
  let fixture: ComponentFixture<HeaderComponent>;
  let connectionState$: BehaviorSubject<MessageBusConnectionState>;

  beforeEach(async () => {
    connectionState$ = new BehaviorSubject<MessageBusConnectionState>('connected');

    await TestBed.configureTestingModule({
      declarations: [ HeaderComponent ],
      providers: [
        {
          provide: TradeFeedService,
          useValue: {
            connectionState$: connectionState$.asObservable()
          }
        },
        {
          provide: StateMetadataService,
          useValue: {
            metadata$: new BehaviorSubject({
              stateId: '009-order-management-matcher',
              stateTitle: 'Order Management and Matcher',
              stateTrack: 'functional',
              generatedAtUtc: '2026-01-01T00:00:00Z',
              sourceBranch: 'test',
              sourceBranchUrl: 'https://example.test',
              lineageLinkUrl: 'https://example.test/lineage',
              apiExplorerUrl: '/api/docs',
              features: { statusPage: true },
              previousStates: [],
              statusChecks: []
            }).asObservable()
          }
        }
      ],
      schemas: [NO_ERRORS_SCHEMA]
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
