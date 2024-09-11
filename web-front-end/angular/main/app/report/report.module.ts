import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { NgxSliderModule } from '@angular-slider/ngx-slider';
import { ReportComponent } from './report.component';
import { ClosedPositionBlotterComponent } from './closed-position-blotter/closed-position-blotter.component';
import { PositionBlotterComponent } from './position-blotter/position-blotter.component';
import { TradeBlotterComponent } from './trade-blotter/trade-blotter.component';
import { AgGridModule } from 'ag-grid-angular';
import { ModalModule } from 'ngx-bootstrap/modal';
import { FormsModule } from '@angular/forms';
import { AlertModule } from 'ngx-bootstrap/alert';
import { DropdownModule } from '../dropdown/dropdown.module';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';

import { TypeaheadModule } from 'ngx-bootstrap/typeahead';

@NgModule({
  declarations: [ReportComponent, TradeBlotterComponent, PositionBlotterComponent, ClosedPositionBlotterComponent],
  imports: [
    CommonModule,
    AgGridModule,
    BrowserAnimationsModule,
    TypeaheadModule.forRoot(),
    ModalModule.forRoot(),
    AlertModule.forRoot(),
    FormsModule,
    DropdownModule,
    NgxSliderModule
  ],
  exports: [ReportComponent, TradeBlotterComponent]
})
export class ReportModule { }
