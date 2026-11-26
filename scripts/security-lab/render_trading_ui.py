"""Select the authenticated limit-order journey; retire legacy direct booking UI."""
from pathlib import Path
from render_account_security import replace_once
from render_order_consumers import section


def apply(target):
    app=Path(target)/'main/app'
    path=app/'trade/trade.component.html';source=path.read_text()
    source=replace_once(source,'''                <button type="button" id="createTicketBtn" class="btn btn-sm btn-primary" (click)="openTicket(tradeTicketTemplate)" [disabled]="isAllAccountsSelected">
                    Create Trade Ticket
                </button>''','''                <span class="text-muted">Security Lab uses explicit limit orders with authenticated settlement.</span>''')
    source=section(source,'            <ng-template #tradeTicketTemplate>','            <ng-template #orderTicketTemplate>','')
    path.write_text(source)
    path=app/'trade/trade.component.ts';source=path.read_text()
    source=section(source,'    createTradeTicket(ticket: TradeTicket) {','    createOrderTicket(','''    createTradeTicket(ticket: TradeTicket) {
        this.createTicketResponse = {success:false, message:'Use the limit-order ticket in the Security Lab.'};
    }
''')
    source=replace_once(source,'''        this.orderAdminService.createOrder(order).subscribe((response) => {
            this.createOrderResponse = response;
            this.activeBlotter = 'orders';
        });''','''        if (!this.accountModel || order.accountId !== this.accountModel.id) {
            this.createOrderResponse = {success:false, message:'Order account changed. Review the selected account.'};
            return;
        }
        this.orderAdminService.createOrder(order).subscribe({
            next: response => { this.createOrderResponse = response; this.activeBlotter = 'orders'; },
            error: () => { this.createOrderResponse = {success:false, message:'Order was not accepted. Check account permission and order terms.'}; }
        });''')
    path.write_text(source)
    path=app/'service/order-admin.service.ts';source=path.read_text()
    source=replace_once(source,"const query = accountId != null ? `?status=open&accountId=${accountId}` : '?status=open';",
        "const query = accountId != null ? `?accountId=${accountId}` : ''; // Owning API scopes rows; the blotter filters terminal orders.")
    path.write_text(source)
    path=app/'service/symbols.service.ts';source=path.read_text()
    source=section(source,'    createTicket(ticket: TradeTicket): Observable<any> {','    private handleError(','''    createTicket(ticket: TradeTicket): Observable<any> {
        return throwError(() => new HttpErrorResponse({status:404, statusText:'Use the authenticated limit-order workflow'}));
    }''')
    path.write_text(source)
    path=app/'trade/order-ticket/order-ticket.component.ts';source=path.read_text()
    source=replace_once(source,"if (!this.ticket.security || this.ticket.quantity <= 0 || this.ticket.limitPrice <= 0)",
        "if (!this.ticket.security || !Number.isSafeInteger(this.ticket.quantity) || this.ticket.quantity <= 0 || !Number.isFinite(this.ticket.limitPrice) || this.ticket.limitPrice <= 0)")
    path.write_text(source)
