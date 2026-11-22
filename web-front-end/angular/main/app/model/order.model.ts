export type OrderStatus = 'NEW' | 'PARTIALLY_FILLED' | 'FILLED' | 'CANCELED' | 'REJECTED';
export type OrderSide = 'Buy' | 'Sell';
export type OrderType = 'MARKET' | 'LIMIT';

export interface OrderRecord {
    orderId: string;
    accountId: number;
    security: string;
    side: OrderSide;
    orderType: OrderType;
    quantity: number;
    remainingQuantity: number;
    limitPrice?: number;
    status: OrderStatus;
    createdAt: string;
    updatedAt: string;
}

export interface OrderCreateRequest {
    accountId: number;
    security: string;
    side: OrderSide;
    orderType: OrderType;
    quantity: number;
    limitPrice?: number;
}
