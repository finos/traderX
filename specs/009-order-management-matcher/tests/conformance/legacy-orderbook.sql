-- Pre-MARKET state-009 persistence fixture, before applying the implementation's upgrade.
CREATE TABLE orderbook (
    orderid VARCHAR(32) PRIMARY KEY,
    accountid INTEGER NOT NULL,
    security VARCHAR(16) NOT NULL,
    side VARCHAR(16) CHECK (side IN ('Buy', 'Sell')),
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    remainingquantity INTEGER NOT NULL CHECK (remainingquantity >= 0),
    limitprice DECIMAL(18,3) NOT NULL,
    status VARCHAR(24) CHECK (status IN ('NEW', 'PARTIALLY_FILLED', 'FILLED', 'CANCELED', 'REJECTED')),
    createdat TIMESTAMP NOT NULL,
    updatedat TIMESTAMP NOT NULL,
    lastexecutionprice DECIMAL(18,3),
    lastfillquantity INTEGER
);
