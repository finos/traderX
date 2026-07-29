export type OrderStatus = 'NEW' | 'PARTIALLY_FILLED' | 'FILLED' | 'CANCELED' | 'REJECTED';
export type OrderSide = 'Buy' | 'Sell';

export interface OrderRecord {
    orderId: string;
    accountId: number;
    security: string;
    side: OrderSide;
    quantity: number;
    remainingQuantity: number;
    limitPrice: number;
    status: OrderStatus;
    createdAt: string;
    updatedAt: string;
}

export interface OrderCreateRequest {
    accountId: number;
    security: string;
    side: OrderSide;
    quantity: number;
    limitPrice: number;
}
