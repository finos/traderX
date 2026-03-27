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
      imports: [
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
    component.positions = positions;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should show given positions in the grid', async () => {
    const columns = fixture.nativeElement.querySelectorAll('.ag-header-cell');
    const rows = fixture.nativeElement.querySelectorAll('.ag-center-cols-container .ag-row');
    expect(columns.length).toEqual(2);
    expect(rows.length).toEqual(2);
    const firstRow = rows[0];
    expect(firstRow.children[0].innerText).toEqual(component.positions[0].security);
    expect(firstRow.children[1].innerText).toEqual(component.positions[0].quantity.toString());
  });

});
