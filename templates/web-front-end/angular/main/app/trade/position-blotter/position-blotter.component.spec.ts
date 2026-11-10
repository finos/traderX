import { HttpClientTestingModule } from '@angular/common/http/testing';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { AgGridModule } from 'ag-grid-angular';
import { PositionBlotterComponent } from './position-blotter.component';
import { PositionService } from 'main/app/service/position.service';
import { MockTradeService, MockTradeFeedService, positions } from 'main/app/test-utils/mocks.service';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

describe('PositionBlotterComponent', () => {
  let component: PositionBlotterComponent;
  let fixture: ComponentFixture<PositionBlotterComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      declarations: [PositionBlotterComponent],
      imports: [HttpClientTestingModule,
        AgGridModule
      ],
      providers: [
        {
          provide: PositionService,
          useClass: MockTradeService
        },
        {
          provide: TradeFeedService,
          useClass: MockTradeFeedService
        }
      ]
    })
      .compileComponents();
  });

  beforeEach(() => {
    fixture = TestBed.createComponent(PositionBlotterComponent);
    component = fixture.componentInstance;
    component.positions = positions.map(position => ({ ...position, security: position.security.toUpperCase() }));
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should show given positions in the grid', async () => {
    await fixture.whenStable();
    await new Promise(resolve => setTimeout(resolve, 100));
    fixture.detectChanges();
    const columns = fixture.nativeElement.querySelectorAll('.ag-header-cell');
    const rows = fixture.nativeElement.querySelectorAll('.ag-center-cols-container .ag-row');
    expect(Array.from(columns as NodeListOf<HTMLElement>).map(column => column.innerText)).toContain('SECURITY');
    expect(Array.from(columns as NodeListOf<HTMLElement>).map(column => column.innerText)).toContain('QUANTITY');
    expect(rows.length).toEqual(2);
    const firstRow = rows[0];
    expect(firstRow.children[0].innerText).toEqual(component.positions[0].security);
    expect(firstRow.children[1].innerText).toEqual(Number(component.positions[0].quantity).toLocaleString('en-US'));
  });

  it('should upsert an existing position row for matching security', async () => {
    await fixture.whenStable();
    await new Promise(resolve => setTimeout(resolve, 100));
    const security = component.positions[0].security;
    const rowCount = component.gridApi.getDisplayedRowCount();

    component.update({ security, quantity: 35, updated: '2026-03-31T00:00:00.000Z' });

    expect(component.gridApi.getRowNode(`Position-${security}`)?.data.quantity).toBe(35);
    expect(component.gridApi.getDisplayedRowCount()).toBe(rowCount);
  });

  it('should keep getRowId callback usable when invoked without component context', () => {
    const detached = component.getRowId;
    const rowId = detached({
      data: {
        security: 'IBM'
      }
    } as any);
    expect(rowId).toBe('Position-IBM');
  });

});
