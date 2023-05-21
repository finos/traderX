export type TradeSide = 'Buy' | 'Sell';

export interface TradeData {
	id?: string;
	accountId?: number;
	security: string;
	side?: TradeSide;
	state?: string;
	quantity: number;
	updated?: Date;
	created?: Date;
}

export interface PositionData {
	accountId: number;
	security: string;
	quantity: number;
	updated: Date;
}