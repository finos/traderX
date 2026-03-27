import { ComponentFixture, TestBed, waitForAsync } from '@angular/core/testing';
import { AccountService } from 'main/app/service/account.service';
import { EditAccountComponent } from './edit.component';
import { FormsModule } from '@angular/forms';
import { AlertModule } from 'ngx-bootstrap/alert';
import { MockAccountService } from 'main/app/test-utils/mocks.service';
import { createAccount } from 'main/app/test-utils/utils';

describe('Account add/update tests', () => {
  let comp: EditAccountComponent;
  let fixture: ComponentFixture<EditAccountComponent>;
  let element: HTMLElement;
  const testAccount = createAccount();
  beforeEach(
    waitForAsync(() => {
      TestBed.configureTestingModule({
        declarations: [EditAccountComponent],
        imports: [
            AlertModule.forRoot(),
            FormsModule
        ],
        providers: [
          {
            provide: AccountService,
            useClass: MockAccountService
          }
        ]
      }).compileComponents();
    })
  );

  beforeEach(() => {
    fixture = TestBed.createComponent(EditAccountComponent);
    comp = fixture.componentInstance;
    element = fixture.debugElement.nativeElement;
    fixture.detectChanges();
  });

  it('should add new account and show success message', () => {
    spyOn(comp.update, 'emit');
    comp.displayName = testAccount.displayName;
    fixture.detectChanges();
    comp.add();

    expect(comp.accountResponse.success).toBe(true);
    expect(comp.accountResponse.msg).toBe('Account added successfully!');
    expect(comp.update.emit).toHaveBeenCalled();
  });

  it('should add update account and show success message', () => {
    spyOn(comp.update, 'emit');
    comp.account =  testAccount;
    fixture.detectChanges();
    comp.add();

    expect(comp.accountResponse.success).toBe(true);
    expect(comp.accountResponse.msg).toBe('Account updated successfully!');
    expect(comp.update.emit).toHaveBeenCalled();
  });

  it('should return if displayName is undefined or empty', () => {
    spyOn(comp.update, 'emit');
    spyOn((<any>comp).accountService, 'addAccount');
    comp.displayName = undefined;
    comp.add();
    expect((<any>comp).accountService.addAccount).not.toHaveBeenCalled();
    expect(comp.update.emit).not.toHaveBeenCalled();
  });

  it('should reset the form', () => {
    comp.displayName = testAccount.displayName;
    comp.account = testAccount;
    expect(comp.displayName).toBeDefined();
    expect(comp.account).toBeDefined();

    comp.reset();

    expect(comp.displayName).toBeUndefined();
    expect(comp.account).toBeUndefined();
  });

  it('should show add button when no existing account available', () => {
    comp.account = undefined;
    fixture.detectChanges();
    expect(element.querySelector('.account-btn')?.textContent?.trim()).toBe('Add Account');
  });

  it('should show update button when an existing account is provided', () => {
    comp.account = testAccount;
    fixture.detectChanges();
    expect(element.querySelector('.account-btn')?.textContent?.trim()).toBe('Update Account');
  });
});
