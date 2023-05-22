import { ICellRendererAngularComp } from 'ag-grid-angular';
import { ICellRendererParams } from 'ag-grid-community';
import { Component, OnDestroy } from '@angular/core';

type ICellParams = ICellRendererParams & { clicked: (val: any) => void };

@Component({
  selector: 'app-btn-cell-renderer',
  template: `
      <button class="btn btn-sm btn-info" (click)="clickHandler()">Update</button>
    `
})
export class ButtonCellRendererComponent implements ICellRendererAngularComp {
  private params: ICellParams;

  agInit(params: ICellParams): void {
    this.params = params;
  }

  clickHandler() {
    console.log(this.params.data);
    this.params.clicked(this.params.data);
  }

  refresh(params: ICellParams) {
    return false;
  }
}
