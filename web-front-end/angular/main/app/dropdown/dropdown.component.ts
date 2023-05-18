import { Component, EventEmitter, Input, OnInit, Output } from "@angular/core";

let id = 0;

@Component({
    selector: 'app-ngx-dropdown',
    templateUrl: './dropdown.component.html'
})
export class DropdownComponent implements OnInit {
    @Input() items: any[];
    @Input() itemKey: string = 'label';
    @Input() selectedItem: any;
    @Input() selectionComparator: (src: any, target: any) => boolean;
    @Output() selectedItemChange = new EventEmitter();
    @Input() placeholder: string = "Please select an item";
    drpId: string;
    drpBtnId: string;

    ngOnInit() {
        this.selectionComparator = this.selectionComparator || this.defaultComparator;
        const uid = id++;
        this.drpId = 'drp' + uid;
        this.drpBtnId = 'drpbtn' + uid;
    }

    defaultComparator = (src: any, target: any) => src === target;

    onItemClick(item: any) {
        if (!this.selectionComparator(this.selectedItem, item)) {
            this.selectedItemChange.emit(item);
        }
    }
}