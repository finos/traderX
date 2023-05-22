import { ComponentFixture, TestBed, waitForAsync, tick, fakeAsync } from '@angular/core/testing';
import { Account } from 'main/app/model/account.model';
import { AccountService } from 'main/app/service/account.service';
import { AssignUserToAccountComponent } from './assign-user.component';
import { FormsModule } from '@angular/forms';
import { AlertModule } from 'ngx-bootstrap/alert';
import { UserService } from 'main/app/service/user.service';
import { User } from 'main/app/model/user.model';
import { MockAccountService, MockUserService } from 'main/app/test-utils/mocks.service';
import { sleep } from 'main/app/test-utils/utils';
import { TypeaheadModule } from 'ngx-bootstrap/typeahead';
import { DropdownModule } from 'main/app/dropdown/dropdown.module';
import { BrowserAnimationsModule } from '@angular/platform-browser/animations';


describe('Assign user to account tests', () => {
  let comp: AssignUserToAccountComponent;
  let fixture: ComponentFixture<AssignUserToAccountComponent>;
  let element: HTMLElement;
  beforeEach(
    waitForAsync(() => {
      TestBed.configureTestingModule({
        declarations: [AssignUserToAccountComponent],
        imports: [DropdownModule, TypeaheadModule.forRoot(), BrowserAnimationsModule, AlertModule.forRoot(), FormsModule],
        providers: [
          {
            provide: AccountService,
            useClass: MockAccountService
          },
          {
            provide: UserService,
            useClass: MockUserService
          }
        ]
      }).compileComponents();
    })
  );

  beforeEach(() => {
    fixture = TestBed.createComponent(AssignUserToAccountComponent);
    comp = fixture.componentInstance;
    element = fixture.debugElement.nativeElement;
    fixture.detectChanges();
  });

  xit('should allow to search user', fakeAsync(() => {
    spyOn((<any>comp).userService, 'getUsers').and.callThrough();
    const typeaheadinput = element.querySelector('#account-user') as HTMLInputElement;
    typeaheadinput.value = 'san';
    typeaheadinput.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    tick(100);
    expect((<any>comp).userService.getUsers).toHaveBeenCalledWith('sa');
  }));

  it('should assign user to account', () => {
    spyOn((<any>comp).accountService, 'addAccountUser').and.callThrough();
    spyOn(comp.update, 'emit');
    spyOn(comp, 'reset');
    comp.user = { logonId: 'test123' } as User;
    comp.account = { id: 1 } as Account;
    comp.add();

    expect((<any>comp).accountService.addAccountUser).toHaveBeenCalled();
    expect(comp.update.emit).toHaveBeenCalled();
    expect(comp.reset).toHaveBeenCalled();
    expect(comp.addUserResponse.success).toBe(true);
    expect(comp.addUserResponse.msg).toBe('User added successfully!');
  });

  it('should node call account service if user or account is undefined', () => {
    spyOn((<any>comp).accountService, 'addAccountUser').and.callThrough();

    comp.user = undefined;
    comp.account = { id: 1 } as Account;
    comp.add();
    expect((<any>comp).accountService.addAccountUser).not.toHaveBeenCalled();

    comp.user = { logonId: 'test123' } as User;
    comp.account = undefined;
    comp.add();
    expect((<any>comp).accountService.addAccountUser).not.toHaveBeenCalled();

    comp.user = undefined;
    comp.account = undefined;
    comp.add();
    expect((<any>comp).accountService.addAccountUser).not.toHaveBeenCalled();

    comp.user = { logonId: 'test123' } as User;
    comp.account = { id: 1 } as Account;
    comp.add();
    expect((<any>comp).accountService.addAccountUser).toHaveBeenCalled();
  });

  it('should close alert after 2 sec', async () => {
    spyOn(comp, 'onCloseAlert').and.callThrough();
    comp.addUserResponse = {};
    fixture.detectChanges();
    await sleep(2500);
    expect(comp.onCloseAlert).toHaveBeenCalled();
    expect(comp.addUserResponse).toBeUndefined();
  });
});
