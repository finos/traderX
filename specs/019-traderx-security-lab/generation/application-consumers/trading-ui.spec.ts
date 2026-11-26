import { of, throwError } from 'rxjs';
import { TradeComponent } from '../trade/trade.component';
import { OrderTicketComponent } from '../trade/order-ticket/order-ticket.component';
import { SymbolService } from '../service/symbols.service';

describe('Authenticated limit-order workflow', () => {
    const order={accountId:62654,security:'IBM',side:'Buy' as const,quantity:10,limitPrice:100};
    it('does not send legacy direct trade tickets', () => {
        const post=jasmine.createSpy('post'); let status=0;
        new SymbolService({post} as any).createTicket(order).subscribe({error:e=>status=e.status});
        expect(post).not.toHaveBeenCalled(); expect(status).toBe(404);
        const legacy=jasmine.createSpy('legacy');
        const component=new TradeComponent({} as any,{createTicket:legacy} as any,{} as any,{} as any,{} as any,{} as any);
        component.accountModel={id:62654} as any;component.createTradeTicket(order);
        expect(legacy).not.toHaveBeenCalled(); expect(component.createTicketResponse.success).toBeFalse();
    });
    it('binds submission to selected account and reports an API denial', () => {
        const createOrder=jasmine.createSpy().and.returnValues(of({orderId:'accepted'}),throwError(()=>({status:403})));
        const component=new TradeComponent({} as any,{} as any,{createOrder} as any,{} as any,{} as any,{} as any);
        component.accountModel={id:62654} as any;
        component.createOrderTicket({...order,accountId:22214}); expect(createOrder).not.toHaveBeenCalled();
        component.createOrderTicket(order);expect(createOrder).toHaveBeenCalledOnceWith(order);
        expect(component.createOrderResponse.orderId).toBe('accepted');expect(component.activeBlotter).toBe('orders');
        component.createOrderTicket(order);expect(component.createOrderResponse.success).toBeFalse();
    });
    it('requires finite explicit price and whole positive quantity', () => {
        const component=new OrderTicketComponent({} as any,{} as any);const create=jasmine.createSpy();
        component.create.subscribe(create);
        for(const invalid of [{...order,limitPrice:0},{...order,limitPrice:Infinity},{...order,quantity:NaN},{...order,quantity:1.5}]) {
            component.ticket=invalid;component.onCreate();
        }
        expect(create).not.toHaveBeenCalled();component.ticket=order;component.onCreate();
        expect(create).toHaveBeenCalledOnceWith(order);
    });
});
