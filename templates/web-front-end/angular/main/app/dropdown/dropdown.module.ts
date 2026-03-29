import { CommonModule } from "@angular/common";
import { NgModule } from "@angular/core";
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';
import { BsDropdownModule } from 'ngx-bootstrap/dropdown';

import { DropdownComponent } from "./dropdown.component";

@NgModule({
    declarations: [DropdownComponent],
    imports: [CommonModule,
        BrowserAnimationsModule,
        BsDropdownModule.forRoot()],
    exports: [DropdownComponent]
})
export class DropdownModule { }