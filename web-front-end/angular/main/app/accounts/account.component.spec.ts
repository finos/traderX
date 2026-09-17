import { ComponentFixture, TestBed, waitForAsync, tick, fakeAsync } from '@angular/core/testing';
import { AccountService } from 'main/app/service/account.service';
import { AccountComponent } from './account.component';
import { MockAccountService } from 'main/app/test-utils/mocks.service';
import { createAccount, sleep } from 'main/app/test-utils/utils';
import { AgGridModule } from 'ag-grid-angular';
import { ButtonCellRendererComponent } from './button-renderer.component';
import { CUSTOM_ELEMENTS_SCHEMA } from '@angular/core';

describe('Account tests', () => {
  let comp: AccountComponent;
  let fixture: ComponentFixture<AccountComponent>;
  let element: HTMLElement;
  beforeEach(
    waitForAsync(() => {
      TestBed.configureTestingModule({
        declarations: [AccountComponent],
        imports: [AgGridModule],
        providers: [
          {
            provide: AccountService,
            useClass: MockAccountService
          }
        ],
        schemas: [CUSTOM_ELEMENTS_SCHEMA]
      }).compileComponents();
    })
  );

  beforeEach(() => {
    fixture = TestBed.createComponent(AccountComponent);
    comp = fixture.componentInstance;
    element = fixture.debugElement.nativeElement;
    fixture.autoDetectChanges(true);
  });

  it('should render the grid and invoke onGridReady hook', async () => {
    spyOn(comp, 'onGridReady').and.callThrough();
    comp.ngOnInit();
    await sleep(250);
    fixture.detectChanges();
    expect(element.querySelector('#accountgrid .ag-root-wrapper')).toBeDefined();
    expect(element.querySelectorAll('#accountgrid .ag-center-cols-container .ag-row').length).toBe(5);
    expect(comp.onGridReady).toHaveBeenCalled();
  });

  it('should fetch accounts list on init', async () => {
    spyOn((<any>comp).accountService, 'getAccounts').and.callThrough();
    expect((<any>comp).accountService.getAccounts).not.toHaveBeenCalled();
    comp.ngOnInit();
    await sleep(250);
    fixture.detectChanges();
    expect((<any>comp).accountService.getAccounts).toHaveBeenCalled();
  });

  it('should select the account from account list', async () => {
    spyOn(comp, 'onSelectionChanged').and.callThrough();
    comp.ngOnInit();
    await sleep(250);
    fixture.detectChanges();
    expect(comp.selectedAccount).toBeUndefined();
    const rows = Array.from(element.querySelectorAll('#accountgrid .ag-row')) as HTMLElement[];
    rows[0].click();
    await sleep(100);
    expect(comp.onSelectionChanged).toHaveBeenCalled();
    expect(comp.selectedAccount).toBeDefined();
  });

  xit('should fetch account users for select account', async () => {
    spyOn((<any>comp).accountService, 'getAccountUsers').and.callThrough();
    comp.ngOnInit();
    fixture.detectChanges();
    await sleep(250)
    expect(element.querySelector('#usergrid .ag-root-wrapper')).toBeDefined();
    expect(element.querySelectorAll('#usergrid .ag-center-cols-container .ag-row').length).toBe(0);

    const rows = Array.from(element.querySelectorAll('#accountgrid .ag-center-cols-container .ag-row')) as HTMLElement[];
    console.log(rows[0]);
    rows[0].click();
    fixture.detectChanges();
    await fixture.whenRenderingDone();

    expect((<any>comp).accountService.getAccountUsers).toHaveBeenCalled();
    expect(element.querySelectorAll('#usergrid .ag-center-cols-container .ag-row').length).toBe(1);
  });

  it('should set account on update callback', () => {
    expect(comp.selectedAccount).toBeUndefined();
    const account = createAccount();
    comp.onUpdate(account);
    expect(comp.selectedAccount).toBe(account);
  });
});
