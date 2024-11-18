import { Component } from '@angular/core';
import { ICellRendererAngularComp } from 'ag-grid-angular';
import { ICellRendererParams } from 'ag-grid-community';

@Component({
  standalone: true,
  template: `{{ txnState }}
    @if (action) {
      <button class="btn btn-sm btn-danger mb-2" (click)="buttonClicked()">{{ action }}</button>
    }`
})
export class TradeStateComponent implements ICellRendererAngularComp {
  static PENDING_STATE: string = 'Pending';
  txnState: string = '';
  action: string = '';

  // constructor(private symbolService: SymbolService) {}

  agInit(params: ICellRendererParams): void {
    if (params.value == TradeStateComponent.PENDING_STATE) {
      this.action = 'Cancel';
    } else {
      this.txnState = params.value + ' ';
    }
  }
  refresh(params: ICellRendererParams) {
    return true;
  }
  buttonClicked() {
    alert('Cancelled trade');
  }
}
