import { ComponentFixture, TestBed, tick, fakeAsync, flush } from '@angular/core/testing';
import { AgGridModule } from 'ag-grid-angular';
import { TradeBlotterComponent } from './trade-blotter.component';
import { PositionService } from 'main/app/service/position.service';
import { MockTradeService, MockTradeFeedService, accounts as dummyAccounts, trades } from 'main/app/test-utils/mocks.service';
import { TradeFeedService } from 'main/app/service/trade-feed.service';

describe('TradeBlotterComponent', () => {
    let component: TradeBlotterComponent;
    let fixture: ComponentFixture<TradeBlotterComponent>;

    beforeEach(async () => {
        await TestBed.configureTestingModule({
            declarations: [TradeBlotterComponent],
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
        }).compileComponents();
    });

    beforeEach(() => {
        fixture = TestBed.createComponent(TradeBlotterComponent);
        component = fixture.componentInstance;
        fixture.detectChanges();
    });

    it('should create', () => {
        expect(component).toBeTruthy();
    });

    it('should show given trades columns in the grid', async () => {
        const columns = fixture.nativeElement.querySelectorAll('.ag-header-cell');
        const rows = fixture.nativeElement.querySelectorAll('.ag-row');
        expect(columns.length).toEqual(4);
        expect(rows.length).toEqual(0);
    });

    it('should call getTrades on changes and set trades', fakeAsync(() => {
        expect(component.account).not.toBeDefined();
        component.ngOnChanges({ account: { currentValue: dummyAccounts[0] } } as any);
        expect(component.trades.length).toEqual(2);
        fixture.detectChanges();
        tick(100);
        flush(); // Flush all pending timers
        const rows = fixture.nativeElement.querySelectorAll('.ag-center-cols-container .ag-row');
        expect(rows.length).toEqual(2);
        expect(component.pendingTrades.length).toEqual(0);
    }));

    it('should call getTrades and subscribe to trade feed service for given account', async () => {
        spyOn((component as any).tradeService, 'getTrades').and.callThrough();
        spyOn((component as any).tradeFeed, 'subscribe').and.callThrough();
        const testAccount = dummyAccounts[0];
        component.ngOnChanges({ account: { currentValue: testAccount } } as any);
        expect((component as any).tradeService.getTrades).toHaveBeenCalledWith(testAccount.id);
        expect((component as any).tradeFeed.subscribe).toHaveBeenCalled();

    });

    it('getRowId should return id from trade data', () => {
        const params = { data: trades[0] } as any;
        expect(component.getRowId(params)).toEqual(`Trade-${trades[0].id}`);
    });

});
