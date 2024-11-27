import { Component } from '@angular/core';
import { ICellRendererAngularComp } from 'ag-grid-angular';
import { ICellRendererParams } from 'ag-grid-community';
import { SymbolService } from 'main/app/service/symbols.service';

@Component({
  standalone: true,
  template: `{{ txnState }}
    @if (action) {
      <button class="btn btn-sm btn-danger mb-2" (click)="buttonClicked()">{{ action }}</button>
    }`
})
export class TradeStateComponent implements ICellRendererAngularComp {
  static PROCESSING_STATE: string = 'Processing';
  txnState: string = '';
  action: string = '';
  valid: boolean = true;
  id: string = '';
  constructor(private symbolService: SymbolService) {}

  agInit(params: ICellRendererParams): void {
    this.id = params.data.id;
    this.txnState = params.data.state + ' ';
    if (params.data.state == TradeStateComponent.PROCESSING_STATE) {
      this.action = 'Cancel?';
    }
  }

  refresh(params: ICellRendererParams) {
    return this.valid;
  }

  buttonClicked() {
    this.symbolService.cancelTrade(this.id)
      .subscribe((response) => console.log("Completed cancel"));
    this.valid = !this.valid;
    alert('Cancelled trade');
  }
}
