export interface Trade {
    accountid: number;
    accountId?: number;
    created: Date;
    id: string;
    quantity: number;
    price?: number;
    security: string;
    side: Side;
    state: State;
    updated: Date;
}

export enum Side {
    Sell = 'Sell',
    Buy = 'Buy'
}

export enum State {
    New = 'New',
    Processing = 'Processing',
    Pending = 'Pending',
    Settled = 'Settled'
}

export interface Position {
    accountid: number;
    accountId?: number;
    quantity: number;
    security: string;
    averageCostBasis?: number;
    marketPrice?: number;
    marketValue?: number;
    costBasisValue?: number;
    pnl?: number;
    updated: Date;
}

export interface TradeTicket {
    side: 'Sell' | 'Buy';
    quantity: number;
    security: string;
    accountId: number;
}

export interface PriceTick {
    ticker: string;
    price: number;
    openPrice: number;
    closePrice: number;
    asOf: string;
    source: string;
}

export interface PortfolioSummary {
    totalMarketValue: number;
    totalCostBasis: number;
    totalPnl: number;
}
