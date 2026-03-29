import { Component, Output, EventEmitter, Input } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { AccountService } from 'main/app/service/account.service';

@Component({
    selector: 'app-edit-account',
    templateUrl: 'edit.component.html',
    styleUrls: ['edit.component.scss']
})
export class EditAccountComponent {
    @Output() update = new EventEmitter<Account>();
    _account?: Account;
    @Input() set account(ac: Account | undefined) {
        this._account = ac;
        if (ac?.displayName) {
            this.displayName = ac.displayName;
        }
    }
    get account() {
        return this._account;
    }
    displayName?: string = undefined;
    accountResponse: any;

    constructor(private accountService: AccountService) { }

    add() {
        if (!this.displayName?.trim()) {
            return;
        }
        const account = Object.assign(this.account || {}, { displayName: this.displayName }) as Account;
        this.accountService.addAccount(account).subscribe(() => {
            this.accountResponse = { success: true, msg: `Account ${account.id ? 'updated' : 'added'} successfully!` };
            this.update.emit(account);
            this.reset();
        }, (err) => {
            console.error(err);
            this.accountResponse = { success: err, msg: `There is some error!` };
        });
    }

    reset() {
        this.account = undefined;
        this.displayName = undefined;
    }

    onCloseAlert() {
        this.accountResponse = undefined;
    }
}
