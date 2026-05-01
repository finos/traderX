import { ComponentFixture, TestBed } from '@angular/core/testing';
import { BehaviorSubject } from 'rxjs';

import { HeaderComponent } from './header.component';
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
