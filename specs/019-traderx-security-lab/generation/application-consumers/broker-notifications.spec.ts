import { TestBed, fakeAsync, tick } from '@angular/core/testing';
import { HttpClient, provideHttpClient } from '@angular/common/http';
import { HttpTestingController, provideHttpClientTesting } from '@angular/common/http/testing';
import { BrokerNotifications, notificationMatches } from './broker-notifications';
import { BrowserSession } from './browser-session';
import { TradeFeedService } from '../service/trade-feed.service';

describe('Mediated broker notifications', () => {
    let backend: HttpTestingController; let session: BrowserSession; let feed: BrokerNotifications;
    const epoch='a'.repeat(32);
    const event={topic:'/accounts/62654/trades', accountId:62654, executionId:'00000000-0000-4000-8000-000000000001',
        eventId:'00000000-0000-4000-8000-000000000001:trade', eventKind:'trade.settled', eventSequence:1};
    beforeEach(() => {
        TestBed.configureTestingModule({providers:[provideHttpClient(),provideHttpClientTesting()]});
        backend=TestBed.inject(HttpTestingController);session=TestBed.inject(BrowserSession);feed=TestBed.inject(BrokerNotifications);
    });
    afterEach(() => {session.clear();feed.ngOnDestroy();backend.verify();});
    function login() {
        session.refresh();backend.expectOne('/session').flush({subject:'lab-trader',csrf:'x'.repeat(43),expiresAt:Date.now()/1000+60});
    }
    function stopWithinClock() {
        // fakeAsync flushes before afterEach: dispose while still in its clock.
        // Keep the session valid while advancing time, so a leaked poll is observable.
        feed.ngOnDestroy();tick(10000);backend.expectNone(request=>request.url.startsWith('/events'));
        session.clear();
    }
    it('polls only after login and never issues browser broker credentials', fakeAsync(() => {
        backend.expectNone('/events');login();
        const first=backend.expectOne('/events');expect(first.request.headers.has('Authorization')).toBeFalse();
        first.flush({cursor:epoch+':0',reset:true,events:[]});
        tick(1000);const second=backend.expectOne('/events?after='+epoch+'%3A0');
        second.flush({cursor:epoch+':0',reset:false,events:[]});
        stopWithinClock();
    }, {flush:false}));
    it('dispatches validated invalidations without financial payloads', fakeAsync(() => {
        const bus=TestBed.inject(TradeFeedService),callback=jasmine.createSpy();
        const remove=bus.subscribeSettlement('/accounts/62654/trades',callback);login();
        backend.expectOne('/events').flush({cursor:epoch+':0',reset:true,events:[]});tick(1000);
        backend.expectOne('/events?after='+epoch+'%3A0').flush({cursor:epoch+':1',reset:false,events:[event]});
        expect(callback).toHaveBeenCalledOnceWith();remove();bus.ngOnDestroy();
        expect(notificationMatches({...event,accountId:22214})).toBeFalse();
        expect(notificationMatches({...event,payload:{price:999}})).toBeFalse();
        stopWithinClock();
    }, {flush:false}));
    it('serializes polls and forces snapshot refresh after a transport gap', fakeAsync(() => {
        const states:string[]=[];feed.connectionState$.subscribe(state=>states.push(state));login();
        const first=backend.expectOne('/events');tick(2000);backend.expectNone('/events');
        first.flush({}, {status:503,statusText:'Offline'});tick(1000);
        backend.expectOne('/events').flush({cursor:epoch+':4',reset:true,events:[]});
        expect(states.slice(-2)).toEqual(['disconnected','connected']);
        stopWithinClock();
    }, {flush:false}));
    it('clears the session and stops polling when broker grants are revoked', fakeAsync(() => {
        login();backend.expectOne('/events').flush({}, {status:403,statusText:'Revoked'});
        expect(session.credentials()).toBeNull();tick(10000);backend.expectNone('/events');
        stopWithinClock();
    }, {flush:false}));
    it('cancels an in-flight poll when the session ends', () => {
        login();const pending=backend.expectOne('/events');session.clear();expect(pending.cancelled).toBeTrue();
    });
    it('rejects malformed pages and restarts from a snapshot reset', fakeAsync(() => {
        const received=jasmine.createSpy();feed.events$.subscribe(received);login();
        backend.expectOne('/events').flush({cursor:epoch+':1',reset:false,events:[{...event,accountId:22214}]});
        expect(received).not.toHaveBeenCalled();tick(1000);
        backend.expectOne('/events').flush({cursor:epoch+':1',reset:true,events:[]});
        stopWithinClock();
    }, {flush:false}));
});
