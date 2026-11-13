import { Component, HostListener, OnDestroy, OnInit, Output, EventEmitter } from '@angular/core';
import { Observable, Subscription } from 'rxjs';
import { StateUiMetadata } from '../model/state-ui-metadata.model';
import { StateMetadataService } from '../service/state-metadata.service';
import { MessageBusConnectionState, TradeFeedService } from '../service/trade-feed.service';

@Component({
    standalone: false,
  selector: 'app-header',
  templateUrl: './header.component.html',
  styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit, OnDestroy {
  @Output() switchTheme = new EventEmitter();

  metadata$: Observable<StateUiMetadata>;
  isSystemMenuOpen = false;
  messageBusState: MessageBusConnectionState = 'connecting';
  messageBusStateLabel = 'Connecting';
  messageBusNotice = '';
  private connectionStateSubscription?: Subscription;
  private reconnectNoticeTimer: ReturnType<typeof setTimeout> | null = null;

  constructor(
    private readonly stateMetadataService: StateMetadataService,
    private readonly tradeFeedService: TradeFeedService
  ) {
    this.metadata$ = this.stateMetadataService.metadata$;
  }

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

  appTitle(stateId: string): string {
    return `TraderX Sample Trading App (${stateId})`;
  }

  toggleSystemMenu(event: MouseEvent): void {
    event.stopPropagation();
    this.isSystemMenuOpen = !this.isSystemMenuOpen;
  }

  closeSystemMenu(): void {
    this.isSystemMenuOpen = false;
  }

  onSystemMenuInteraction(event: MouseEvent): void {
    event.stopPropagation();
  }

  @HostListener('document:click')
  onDocumentClick(): void {
    this.closeSystemMenu();
  }

  @HostListener('document:keydown.escape')
  onEscapeKey(): void {
    this.closeSystemMenu();
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
