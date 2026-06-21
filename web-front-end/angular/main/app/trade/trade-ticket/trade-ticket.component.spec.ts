import { ComponentFixture, TestBed } from '@angular/core/testing';

import { TradeTicketComponent } from './trade-ticket.component';
import { By } from '@angular/platform-browser';
import { FormsModule } from '@angular/forms';
import { stocks as dummyStocks, accounts as dummyAccounts } from 'main/app/test-utils/mocks.service';
import { TypeaheadModule } from 'ngx-bootstrap/typeahead';

xdescribe('TradeTicketComponent', () => {
  let component: TradeTicketComponent;
  let fixture: ComponentFixture<TradeTicketComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [TradeTicketComponent],
      imports: [
        FormsModule,
        TypeaheadModule
      ]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(TradeTicketComponent);
    component = fixture.componentInstance;
    component.account = dummyAccounts[0];
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should show ticket with initial values', async () => {
    await fixture.whenStable();
    const quantityField = fixture.debugElement.query(By.css('#quantityField'));
    expect(quantityField.nativeElement.value).toEqual('0');
    const buyButton = fixture.debugElement.query(By.css('#buyButton'));
    expect(buyButton.nativeElement.checked).toBeTrue();
    const accountLabel = fixture.debugElement.query(By.css('#accountLabel'));
    expect(accountLabel.nativeElement.innerText).toEqual(component.account?.displayName);
  });

  it('should update ticket object with given values on create click and emit create event', async () => {
    const quantityField = fixture.debugElement.query(By.css('#quantityField'));
    quantityField.nativeElement.value = 10;
    quantityField.nativeElement.dispatchEvent(new Event('input'));
    const sellButton = fixture.debugElement.query(By.css('#sellButton'));
    sellButton.nativeElement.click();
    component.ticket.security = dummyStocks[0].ticker;

    spyOn(component.create, 'emit');
    const createButton = fixture.debugElement.query(By.css('#createButton'));
    createButton.nativeElement.click();
    fixture.detectChanges();

    expect(component.create.emit).toHaveBeenCalledWith(
      {
        quantity: 10, accountId: component.account?.id as any, side: 'Sell', security: component.ticket.security
      });
  });

  // it('getStockTicker should return ticker value from stock', () => {
  //   expect(component.getStockTicker(dummyStocks[0])).toEqual(dummyStocks[0].ticker);
  // });

  // it('getStockLabel should return comapny name from stock', () => {
  //   expect(component.getStockLabel(dummyStocks[0])).toEqual(dummyStocks[0].companyName);
  // });

  it('should emit cancel on cancel click', async () => {
    spyOn(component.cancel, 'emit');
    const cancelButton = fixture.debugElement.query(By.css('#cancelButton'));
    cancelButton.nativeElement.click();
    fixture.detectChanges();
    expect(component.cancel.emit).toHaveBeenCalled();
  });

  it('onQueryChange should return results based on given query', () => {
    component.stocks = dummyStocks;
    expect(component.filteredStocks.length).toEqual(0);
    const stockInput = fixture.debugElement.query(By.css('#stock-input'));
    stockInput.nativeElement.value = '';
    stockInput.nativeElement.dispatchEvent(new Event('input'));
    expect(component.filteredStocks.length).toEqual(5);
  });

});
