import { Component, OnDestroy, OnInit, Output, EventEmitter } from '@angular/core';
import { Subscription } from 'rxjs';
import { MessageBusConnectionState, TradeFeedService } from '../service/trade-feed.service';

@Component({
    standalone: false,
  selector: 'app-header',
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit, OnDestroy {
  @Output() switchTheme = new EventEmitter();

  messageBusState: MessageBusConnectionState = 'connecting';
  messageBusStateLabel = 'Connecting';
  messageBusNotice = '';
  private connectionStateSubscription?: Subscription;
  private reconnectNoticeTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(private readonly tradeFeedService: TradeFeedService) {}

  ngOnInit(): void {
    let previousState: MessageBusConnectionState = this.messageBusState;
    this.connectionStateSubscription = this.tradeFeedService.connectionState$.subscribe((state) => {
      this.messageBusState = state;
      this.messageBusStateLabel = this.toStateLabel(state);
      if (previousState === 'disconnected' && state === 'connected') {
        this.messageBusNotice = 'message bus reconnected';
        this.scheduleNoticeClear();
      }
      previousState = state;
    });
  }

  ngOnDestroy(): void {
    this.connectionStateSubscription?.unsubscribe();
    this.clearNoticeTimer();
  }

  private toStateLabel(state: MessageBusConnectionState): string {
    if (state === 'connected') {
      return 'Connected';
    }
    if (state === 'disconnected') {
      return 'Disconnected';
    }
    return 'Connecting';
  }

  private scheduleNoticeClear(): void {
    this.clearNoticeTimer();
    this.reconnectNoticeTimer = setTimeout(() => {
      this.messageBusNotice = '';
      this.reconnectNoticeTimer = null;
    }, 2500);
  }

  private clearNoticeTimer(): void {
    if (this.reconnectNoticeTimer !== null) {
      clearTimeout(this.reconnectNoticeTimer);
      this.reconnectNoticeTimer = null;
    }
  }
}
