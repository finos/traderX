export interface Account {
    id: number;
    displayName: string;
    /** Settlement desk identifier used by the post-trade settle flow (016). */
    name?: string;
}
