import { NgModule } from '@angular/core';
import { CommonModule } from '@angular/common';
import { AccountComponent } from './account.component';
import { AgGridModule } from 'ag-grid-angular';
import { EditAccountComponent } from './edit/edit.component';
import { FormsModule } from '@angular/forms';
import { ButtonCellRendererComponent } from './button-renderer.component';
import { AssignUserToAccountComponent } from './user/assign-user.component';
import { TypeaheadModule } from 'ngx-bootstrap/typeahead';
import { AlertModule } from 'ngx-bootstrap/alert';
import { DropdownModule } from '../dropdown/dropdown.module';

@NgModule({
  declarations: [AccountComponent, EditAccountComponent, AssignUserToAccountComponent],
  imports: [
    CommonModule,
    FormsModule,
    TypeaheadModule.forRoot(),
    DropdownModule,
    AlertModule.forRoot(),
    AgGridModule
  ],
  exports: [AccountComponent, EditAccountComponent, AssignUserToAccountComponent]
})
export class AccountsModule { }
