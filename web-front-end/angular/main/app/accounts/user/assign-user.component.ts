import { catchError } from 'rxjs/operators';
import { Component, EventEmitter, Input, OnInit, Output } from '@angular/core';
import { Account } from 'main/app/model/account.model';
import { User } from 'main/app/model/user.model';
import { AccountService } from 'main/app/service/account.service';
import { UserService } from 'main/app/service/user.service';
import { TypeaheadMatch } from 'ngx-bootstrap/typeahead';
import { map, noop, Observable, Observer, of, switchMap, tap } from 'rxjs';

@Component({
    selector: 'app-assign-user',
    templateUrl: 'assign-user.component.html'
})
export class AssignUserToAccountComponent implements OnInit {
    @Input() accounts: any = [];
    @Input() account?: Account = undefined;
    users$: Observable<User[]>;
    user?: User = undefined;
    search?: string = undefined;
    addUserResponse: any;
    @Output() update = new EventEmitter<Account>();
    constructor(private userService: UserService, private accountService: AccountService) { }

    ngOnInit(): void {
        this.users$ = new Observable((observer: Observer<string | undefined>) => {
            observer.next(this.search as string | undefined);
        }).pipe(
            switchMap<string, Observable<User[]>>((query: string) => {
                if (query && query.length > 2) {
                    return this.userService.getUsers(query).pipe(
                        map((data: User[]) => data || []),
                        tap(() => noop, err => {
                            console.log(err && err.message || 'Something goes wrong');
                        }),
                        catchError(() => of([]))
                    );
                }
                return of([]);
            })
        );
    }

    comparatorFunction(src: Account, target: Account) {
        return src?.id === target?.id;
    }

    add() {
        if (!this.user || !this.account) {
            return;
        }
        const accountUser = { username: this.user.logonId, accountId: this.account.id };
        this.accountService.addAccountUser(accountUser).subscribe(() => {
            this.addUserResponse = { success: true, msg: 'User added successfully!' };
            this.update.emit(this.account);
            this.reset(true);
        }, (err) => {
            this.addUserResponse = { error: true, msg: 'There is some error!' };
            console.error(err);
        });
    }

    onSelect(event: TypeaheadMatch) {
        this.user = event.item;
    }

    reset(fromAdd: boolean = false) {
        this.user = undefined;
        this.search = undefined;
        // keep account sticky if we are just adding a user
        if(!fromAdd)
            this.account = undefined;
    }

    onCloseAlert() {
        this.addUserResponse = undefined;
    }
}
