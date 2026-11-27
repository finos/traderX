import { fakeAsync, tick } from '@angular/core/testing';
import { of, Subject, throwError } from 'rxjs';
import { OrderBlotterComponent } from '../trade/order-blotter/order-blotter.component';
import { OrderTicketComponent } from '../trade/order-ticket/order-ticket.component';

function bus() {
    const state=new Subject<string>(); const callbacks=new Map<string,()=>void>();
    return {state,callbacks,connectionState$:state.asObservable(),
        subscribe:()=>()=>{},subscribeSettlement:(topic:string,callback:()=>void)=>{callbacks.set(topic,callback);return()=>callbacks.delete(topic);}};
}
function row(accountId:number,id='own') {return {accountId,orderId:id,security:'IBM',side:'Buy',quantity:10,remainingQuantity:10,limitPrice:100,status:'NEW'};}

describe('Actual scoped order snapshot consumers', () => {
    it('filters foreign and terminal orders, then refreshes after settlement and polling', fakeAsync(() => {
        const feed=bus();const api={getOpenOrders:jasmine.createSpy().and.returnValue(of([row(22214),row(62654,'foreign'),{...row(22214,'done'),status:'FILLED'}]))};
        const component=new OrderBlotterComponent(api as any,feed as any,{getPrices:()=>of([])} as any);
        component.account={id:22214} as any;component.ngOnChanges({account:{} as any});tick(100);
        expect(component.rows.map(x=>x.orderId)).toEqual(['own']);
        api.getOpenOrders.and.returnValue(of([]));feed.callbacks.get('/accounts/22214/trades')!();tick(100);
        expect(component.rows).toEqual([]);tick(2100);expect(api.getOpenOrders.calls.count()).toBeGreaterThan(2);
        component.ngOnDestroy();
    }));
    it('immediately clears old rows and cancels old-account requests on scope changes', fakeAsync(() => {
        const pending=new Subject<any[]>();const feed=bus();const api={getOpenOrders:jasmine.createSpy().and.returnValues(pending,of([row(62654,'new')]))};
        const component=new OrderBlotterComponent(api as any,feed as any,{getPrices:()=>of([])} as any);
        component.account={id:22214} as any;component.ngOnChanges({account:{} as any});tick(100);
        component.account={id:62654} as any;component.ngOnChanges({account:{} as any});
        expect(component.rows).toEqual([]);expect(pending.observed).toBeFalse();tick(100);
        pending.next([row(22214,'private-old')]);expect(component.rows.map(x=>x.orderId)).toEqual(['new']);
        component.ngOnDestroy();const calls=api.getOpenOrders.calls.count();tick(10000);expect(api.getOpenOrders.calls.count()).toBe(calls);
    }));
    it('clears denied snapshots and reports cancellation denial without trusting an event payload', fakeAsync(() => {
        const feed=bus();const api={getOpenOrders:jasmine.createSpy().and.returnValues(of([row(22214)]),throwError(()=>new Error('denied'))),cancelOrder:()=>throwError(()=>new Error('denied'))};
        const component=new OrderBlotterComponent(api as any,feed as any,{getPrices:()=>of([])} as any);
        component.account={id:22214} as any;component.ngOnChanges({account:{} as any});tick(100);
        component.onCellClicked({colDef:{colId:'cancel'},data:row(22214)} as any);tick(100);
        expect(component.rows).toEqual([]);expect(component.actionError).toContain('Cancellation was not accepted');component.ngOnDestroy();
    }));
    it('uses only known account IDs in all-account mode', fakeAsync(() => {
        const api={getOpenOrders:()=>of([row(22214),row(62654,'foreign')])};const feed=bus();
        const component=new OrderBlotterComponent(api as any,feed as any,{getPrices:()=>of([])} as any);
        component.allAccountsMode=true;component.accountNameById={22214:'Known'};component.ngOnChanges({allAccountsMode:{} as any});tick(100);
        expect(component.rows.map(x=>x.accountId)).toEqual([22214]);component.ngOnDestroy();
    }));
    it('polls selected quote snapshots and discards the previous ticker response', fakeAsync(() => {
        const pending=new Subject<any>();const quotes={getPrice:jasmine.createSpy().and.returnValues(pending,of({ticker:'MSFT',price:20,asOf:'2026-11-26T00:00:00Z'}))};
        const component=new OrderTicketComponent(bus() as any,quotes as any);
        component.onSelect({item:{ticker:'IBM',companyName:'IBM'}} as any);tick(100);
        component.onSelect({item:{ticker:'MSFT',companyName:'Microsoft'}} as any);tick(100);
        expect(pending.observed).toBeFalse();pending.next({ticker:'IBM',price:999});expect(component.selectedPrice).toBe(20);
        quotes.getPrice.and.returnValue(of({ticker:'MSFT',price:21,asOf:'2026-11-26T00:00:01Z'}));tick(2100);
        expect(component.selectedPrice).toBe(21);component.ngOnDestroy();
    }));
});
