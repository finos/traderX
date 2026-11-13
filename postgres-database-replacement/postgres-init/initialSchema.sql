DROP TABLE IF EXISTS trades;
DROP TABLE IF EXISTS orderbook;
DROP TABLE IF EXISTS accountusers;
DROP TABLE IF EXISTS positions;
DROP TABLE IF EXISTS accounts;
DROP SEQUENCE IF EXISTS accounts_seq;

CREATE TABLE accounts (
  id INTEGER PRIMARY KEY,
  displayname VARCHAR(50)
);

CREATE TABLE accountusers (
  accountid INTEGER NOT NULL,
  username VARCHAR(15) NOT NULL,
  PRIMARY KEY (accountid, username),
  FOREIGN KEY (accountid) REFERENCES accounts(id)
);

CREATE TABLE positions (
  accountid INTEGER,
  security VARCHAR(15),
  updated TIMESTAMP,
  quantity INTEGER,
  averagecostbasis DECIMAL(18,3),
  PRIMARY KEY (accountid, security),
  FOREIGN KEY (accountid) REFERENCES accounts(id)
);

CREATE TABLE trades (
  id VARCHAR(50) PRIMARY KEY,
  accountid INTEGER REFERENCES accounts(id),
  created TIMESTAMP,
  updated TIMESTAMP,
  security VARCHAR(15),
  side VARCHAR(10) CHECK (side in ('Buy', 'Sell')),
  quantity INTEGER CHECK (quantity > 0),
  price DECIMAL(18,3),
  state VARCHAR(20) CHECK (state in ('New', 'Processing', 'Settled', 'Cancelled'))
);

CREATE TABLE orderbook (
  orderid VARCHAR(32) PRIMARY KEY,
  accountid INTEGER NOT NULL,
  security VARCHAR(16) NOT NULL,
  side VARCHAR(16) CHECK (side in ('Buy', 'Sell')),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  remainingquantity INTEGER NOT NULL CHECK (remainingquantity >= 0),
  limitprice DECIMAL(18,3) NOT NULL,
  status VARCHAR(24) CHECK (status in ('NEW', 'PARTIALLY_FILLED', 'FILLED', 'CANCELED', 'REJECTED')),
  createdat TIMESTAMP NOT NULL,
  updatedat TIMESTAMP NOT NULL,
  lastexecutionprice DECIMAL(18,3),
  lastfillquantity INTEGER
);
CREATE INDEX idx_orderbook_status ON orderbook(status);
CREATE INDEX idx_orderbook_updatedat ON orderbook(updatedat);

CREATE SEQUENCE accounts_seq START WITH 65000 INCREMENT BY 1;

INSERT INTO accounts (id, displayname) VALUES (22214, 'Test Account 20');
INSERT INTO accounts (id, displayname) VALUES (11413, 'Private Clients Fund TTXX');
INSERT INTO accounts (id, displayname) VALUES (42422, 'Algo Execution Partners');
INSERT INTO accounts (id, displayname) VALUES (52355, 'Big Corporate Fund');
INSERT INTO accounts (id, displayname) VALUES (62654, 'Hedge Fund TXY1');
INSERT INTO accounts (id, displayname) VALUES (10031, 'Internal Trading Book');
INSERT INTO accounts (id, displayname) VALUES (44044, 'Trading Account 1');

INSERT INTO accountusers (accountid, username) VALUES (22214, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user03');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user05');
INSERT INTO accountusers (accountid, username) VALUES (22214, 'user07');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user05');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user07');
INSERT INTO accountusers (accountid, username) VALUES (62654, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (10031, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (10031, 'user03');
INSERT INTO accountusers (accountid, username) VALUES (10031, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user09');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user05');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user07');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user04');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user01');
INSERT INTO accountusers (accountid, username) VALUES (44044, 'user06');

INSERT INTO trades (id, created, updated, security, side, quantity, price, state, accountid) VALUES ('TRADE-22214-AABBCC', NOW(), NOW(), 'IBM', 'Sell', 100, 136.250, 'Settled', 22214);
INSERT INTO trades (id, created, updated, security, side, quantity, price, state, accountid) VALUES ('TRADE-22214-DDEEFF', NOW(), NOW(), 'MS', 'Buy', 1000, 95.125, 'Settled', 22214);
INSERT INTO trades (id, created, updated, security, side, quantity, price, state, accountid) VALUES ('TRADE-22214-GGHHII', NOW(), NOW(), 'C', 'Sell', 2000, 57.500, 'Settled', 22214);

INSERT INTO positions (accountid, security, updated, quantity, averagecostbasis) VALUES (22214, 'MS', NOW(), 1000, 95.125);
INSERT INTO positions (accountid, security, updated, quantity, averagecostbasis) VALUES (22214, 'IBM', NOW(), -100, 136.250);
INSERT INTO positions (accountid, security, updated, quantity, averagecostbasis) VALUES (22214, 'C', NOW(), -2000, 57.500);

INSERT INTO trades (id, created, updated, security, side, quantity, price, state, accountid) VALUES ('TRADE-52355-AABBCC', NOW(), NOW(), 'BAC', 'Sell', 2400, 41.125, 'Settled', 52355);
INSERT INTO positions (accountid, security, updated, quantity, averagecostbasis) VALUES (52355, 'BAC', NOW(), -2400, 41.125);
