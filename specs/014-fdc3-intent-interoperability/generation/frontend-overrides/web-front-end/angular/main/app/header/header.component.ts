import { Component, OnInit, Output, EventEmitter, ElementRef, AfterViewInit, OnDestroy } from '@angular/core';
import { Subscription } from 'rxjs';
import { Fdc3InteropService } from '../service/fdc3-interop.service';

@Component({
    standalone: false,
    selector: 'app-header',
    templateUrl: './header.component.html',
    styleUrls: ['./header.component.scss']
})
export class HeaderComponent implements OnInit, AfterViewInit, OnDestroy {

    @Output() switchTheme = new EventEmitter();
    fdc3AgentAvailable = false;
    fdc3StatusMessage = 'FDC3: connecting...';

    private resizeObserver?: ResizeObserver;
    private readonly onWindowResize = () => this.updateHeaderHeightCssVar();
    private readonly interopSubscriptions = new Subscription();

    constructor(
        private elementRef: ElementRef<HTMLElement>,
        private fdc3Interop: Fdc3InteropService
    ) {}

    ngOnInit(): void {
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
    }

    private updateHeaderHeightCssVar(): void {
        const hostHeight = Math.ceil(this.elementRef.nativeElement.getBoundingClientRect().height);
        document.documentElement.style.setProperty('--traderx-header-height', `${hostHeight}px`);
    }
}
