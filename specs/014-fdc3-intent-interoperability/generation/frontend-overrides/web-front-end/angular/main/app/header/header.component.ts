import { Component, OnInit, Output, EventEmitter, ElementRef, AfterViewInit, OnDestroy, HostListener } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';
import { Observable, Subscription } from 'rxjs';
import { Fdc3InteropService } from '../service/fdc3-interop.service';
import { StateUiMetadata } from '../model/state-ui-metadata.model';
import { StateMetadataService } from '../service/state-metadata.service';
import { MessageBusConnectionState, TradeFeedService } from '../service/trade-feed.service';

@Component({
    standalone: false,
    selector: 'app-header',
    templateUrl: './header.component.html',
    styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit, AfterViewInit, OnDestroy {

    @Output() switchTheme = new EventEmitter();
    metadata$: Observable<StateUiMetadata>;
    isSystemMenuOpen = false;
    fdc3AgentAvailable = false;
    fdc3StatusMessage = 'FDC3: connecting...';
    isMiniTraderxRoute = false;
    messageBusState: MessageBusConnectionState = 'connecting';
    messageBusStateLabel = 'Connecting';
    messageBusNotice = '';

    private resizeObserver?: ResizeObserver;
    private readonly onWindowResize = () => this.updateHeaderHeightCssVar();
    private readonly interopSubscriptions = new Subscription();
    private reconnectNoticeTimer: ReturnType<typeof setTimeout> | null = null;

    constructor(
        private elementRef: ElementRef<HTMLElement>,
        private fdc3Interop: Fdc3InteropService,
        private router: Router,
        private stateMetadataService: StateMetadataService,
        private tradeFeedService: TradeFeedService
    ) {
        this.metadata$ = this.stateMetadataService.metadata$;
    }

    ngOnInit(): void {
        this.updateRouteMode(this.router.url);
        this.interopSubscriptions.add(
            this.router.events.subscribe((event) => {
                if (event instanceof NavigationEnd) {
                    this.updateRouteMode(event.urlAfterRedirects);
                }
            })
        );
        this.interopSubscriptions.add(
            this.fdc3Interop.isAgentAvailable$.subscribe((available) => {
                this.fdc3AgentAvailable = available;
            })
        );
        this.interopSubscriptions.add(
            this.fdc3Interop.statusMessage$.subscribe((message) => {
                this.fdc3StatusMessage = message;
            })
        );
        let previousState: MessageBusConnectionState = this.messageBusState;
        this.interopSubscriptions.add(
            this.tradeFeedService.connectionState$.subscribe((state) => {
                this.messageBusState = state;
                this.messageBusStateLabel = this.toStateLabel(state);
                if (previousState === 'disconnected' && state === 'connected') {
                    this.messageBusNotice = 'message bus reconnected';
                    this.scheduleNoticeClear();
                }
                previousState = state;
            })
        );
        this.fdc3Interop.initialize().catch((error) => {
            console.warn('[fdc3] initialization failed', error);
            this.fdc3StatusMessage = 'FDC3 initialization failed';
        });
    }

    ngAfterViewInit(): void {
        this.updateHeaderHeightCssVar();
        if (typeof ResizeObserver !== 'undefined') {
            this.resizeObserver = new ResizeObserver(() => this.updateHeaderHeightCssVar());
            this.resizeObserver.observe(this.elementRef.nativeElement);
            return;
        }
        window.addEventListener('resize', this.onWindowResize);
    }

    ngOnDestroy(): void {
        if (this.resizeObserver) {
            this.resizeObserver.disconnect();
            this.resizeObserver = undefined;
        } else {
            window.removeEventListener('resize', this.onWindowResize);
        }
        this.interopSubscriptions.unsubscribe();
        this.fdc3Interop.destroy();
        this.clearNoticeTimer();
    }

    appTitle(stateId: string): string {
        if (this.isMiniTraderxRoute) {
            return 'Mini TraderX';
        }
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

    private updateHeaderHeightCssVar(): void {
        if (this.isMiniTraderxRoute) {
            document.documentElement.style.setProperty('--traderx-header-height', '0px');
            return;
        }
        const hostHeight = Math.ceil(this.elementRef.nativeElement.getBoundingClientRect().height);
        document.documentElement.style.setProperty('--traderx-header-height', `${hostHeight}px`);
    }

    private updateRouteMode(url: string): void {
        const path = String(url || '').split('?')[0].split('#')[0];
        this.isMiniTraderxRoute = path.endsWith('/mini-traderx');
        setTimeout(() => this.updateHeaderHeightCssVar());
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
