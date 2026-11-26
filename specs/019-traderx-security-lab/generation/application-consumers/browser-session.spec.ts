import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { HttpClient, provideHttpClient, withInterceptors } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { BrowserSession, browserSessionInterceptor } from './browser-session';
import { TradeFeedService } from '../service/trade-feed.service';
import { Component, EventEmitter, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AppComponent } from '../app.component';
import { ThemeService } from '../service/theme.service';

describe('Application browser session', () => {
    let session: BrowserSession; let http: HttpClient; let backend: HttpTestingController;
    const csrf = 'a'.repeat(43);
    beforeEach(() => {
        TestBed.configureTestingModule({providers: [provideHttpClient(withInterceptors([browserSessionInterceptor])), provideHttpClientTesting()]});
        session = TestBed.inject(BrowserSession); http = TestBed.inject(HttpClient); backend = TestBed.inject(HttpTestingController);
    });
    afterEach(() => { session.clear(); backend.verify(); });
    function login(seconds = 60) {
        session.refresh();
        backend.expectOne('/session').flush({subject:'lab-trader', csrf, expiresAt:Date.now()/1000 + seconds});
    }
    it('refuses application requests until a valid cookie session is established', () => {
        let status=0;
        http.get('/position-service/positions/').subscribe({error:e => status=e.status});
        expect(status).toBe(401); backend.expectNone('/api/position-service/positions/');
        session.refresh(); backend.expectOne('/session').flush({subject:'trader', csrf, expiresAt:0});
        expect(session.credentials()).toBeNull();
    });
    it('uses the same-origin boundary and session CSRF, stripping caller authority', () => {
        login();
        http.post('/order-matcher/orders', {accountId:62654}, {headers:{Authorization:'Bearer caller', 'X-CSRF-Token':'caller', 'X-Role':'operator', 'X-Account-Id':'22214'}}).subscribe();
        const sent=backend.expectOne('/api/order-matcher/orders');
        expect(sent.request.headers.get('X-CSRF-Token')).toBe(csrf);
        for (const name of ['Authorization','X-Role','X-Account-Id']) expect(sent.request.headers.has(name)).toBeFalse();
        sent.flush({});
        http.get('/position-service/trades/62654').subscribe();
        const read=backend.expectOne('/api/position-service/trades/62654');
        expect(read.request.headers.has('X-CSRF-Token')).toBeFalse(); read.flush([]);
    });
    it('does not send session material to external API destinations', () => {
        login(); let status=0;
        http.post('https://untrusted.invalid/order-matcher/orders',{}).subscribe({error:e => status=e.status});
        expect(status).toBe(403); backend.expectNone('https://untrusted.invalid/order-matcher/orders');
    });
    it('expires the view and cancels outstanding old-session reads', fakeAsync(() => {
        login(1); const apply=jasmine.createSpy();
        http.get('/position-service/trades/').subscribe(apply);
        const pending=backend.expectOne('/api/position-service/trades/');
        tick(1000);
        expect(session.credentials()).toBeNull(); expect(session.subject).toBe('');
        expect(pending.cancelled).toBeTrue(); expect(apply).not.toHaveBeenCalled();
    }));
    it('clears peer requests on an API 401 without inventing a token refresh', () => {
        login();
        http.get('/position-service/trades/').subscribe({error:()=>{}});
        http.get('/position-service/positions/').subscribe();
        const first=backend.expectOne('/api/position-service/trades/');
        const second=backend.expectOne('/api/position-service/positions/');
        first.flush({}, {status:401,statusText:'Expired'});
        expect(second.cancelled).toBeTrue(); expect(session.credentials()).toBeNull();
        backend.expectNone('/session');
    });
    it('clears local state immediately and sends logout with CSRF', () => {
        login(); session.logout(); expect(session.credentials()).toBeNull();
        const logout=backend.expectOne('/logout');
        expect(logout.request.headers.get('X-CSRF-Token')).toBe(csrf);
        expect(logout.request.headers.has('Authorization')).toBeFalse(); logout.flush({});
    });
    it('bounds an unresponsive session check and keeps views signed out', fakeAsync(() => {
        session.refresh(); const pending=backend.expectOne('/session'); tick(5000);
        expect(pending.cancelled).toBeTrue(); expect(session.credentials()).toBeNull();
    }));
    it('reports uncertain server logout while keeping the local view cleared', () => {
        login(); session.logout();
        backend.expectOne('/logout').flush({}, {status:503,statusText:'Unavailable'});
        expect(session.logoutUnconfirmed).toBeTrue(); expect(session.credentials()).toBeNull();
    });
    it('does not open the inherited anonymous NATS socket in the session candidate', () => {
        const socket=spyOn(window,'WebSocket');
        const bus=TestBed.inject(TradeFeedService);
        const remove=bus.subscribeSettlement('/accounts/62654/trades',()=>{});
        expect(socket).not.toHaveBeenCalled(); remove();
    });
});

@Component({standalone:false, selector:'app-header', template:''})
class HeaderStub { @Output() switchTheme=new EventEmitter<void>(); }
let destroyedViews=0;
@Component({standalone:false, selector:'router-outlet', template:'Private account view'})
class RoutedViewStub { ngOnDestroy() { destroyedViews++; } }

describe('Actual application session gate', () => {
    beforeEach(async () => {
        destroyedViews=0;
        await TestBed.configureTestingModule({
            imports:[CommonModule], declarations:[AppComponent,HeaderStub,RoutedViewStub],
            providers:[provideHttpClient(),provideHttpClientTesting(),{provide:ThemeService,useValue:{switchTheme:()=>{}}}]
        }).compileComponents();
    });
    it('constructs account views only after login and destroys them at expiry', fakeAsync(() => {
        const backend=TestBed.inject(HttpTestingController);
        const fixture=TestBed.createComponent(AppComponent); fixture.detectChanges();
        expect(fixture.nativeElement.textContent).not.toContain('Private account view');
        backend.expectOne('/session').flush({subject:'lab-reader',csrf:'a'.repeat(43),expiresAt:Date.now()/1000+1});
        fixture.detectChanges(); expect(fixture.nativeElement.textContent).toContain('Private account view');
        tick(1000); fixture.detectChanges();
        expect(fixture.nativeElement.textContent).not.toContain('Private account view');
        expect(fixture.nativeElement.textContent).toContain('Sign in with Keycloak');
        expect(destroyedViews).toBe(1); fixture.destroy(); backend.verify();
    }));
});
