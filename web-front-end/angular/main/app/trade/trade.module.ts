import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TradeTicketComponent } from './trade-ticket/trade-ticket.component';
import { TradeComponent } from './trade.component';
import { TradeBlotterComponent } from './trade-blotter/trade-blotter.component';
import { AgGridModule } from 'ag-grid-angular';
import { ModalModule } from 'ngx-bootstrap/modal';
import { FormsModule } from '@angular/forms';
import { AlertModule } from 'ngx-bootstrap/alert';
import { PositionBlotterComponent } from './position-blotter/position-blotter.component';
import { DropdownModule } from '../dropdown/dropdown.module';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';

import { TypeaheadModule } from 'ngx-bootstrap/typeahead';

@NgModule({
  declarations: [TradeComponent, TradeTicketComponent, TradeBlotterComponent, PositionBlotterComponent],
  imports: [
    CommonModule,
    AgGridModule,
    BrowserAnimationsModule,
    TypeaheadModule.forRoot(),
    ModalModule.forRoot(),
    AlertModule.forRoot(),
    FormsModule,
    DropdownModule
  ],
  exports: [TradeComponent, TradeTicketComponent, TradeBlotterComponent]
})
export class TradeModule { }
