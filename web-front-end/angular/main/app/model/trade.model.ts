export interface Trade {
    accountid: number;
    created: Date;
    id: string;
    quantity: number;
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
    quantity: number;
    security: string;
    updated: Date;
}

export interface TradeTicket {
    id: string;
    side: 'Sell' | 'Buy';
    action: 'BUYSTOCK' | 'SELLSTOCK' | 'CANCELTRADE';
    state: 'New';
    quantity: number;
    security: string;
    accountId: number;
}
