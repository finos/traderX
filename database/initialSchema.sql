-- PostgreSQL compatible schema
DROP TABLE IF EXISTS Trades CASCADE;

DROP TABLE IF EXISTS AccountUsers CASCADE; 

DROP TABLE IF EXISTS Positions CASCADE; 

DROP TABLE IF EXISTS Accounts CASCADE; 

DROP SEQUENCE IF EXISTS ACCOUNTS_SEQ;

CREATE TABLE Accounts ( 
    ID INTEGER PRIMARY KEY, 
    DisplayName VARCHAR(50) 
); 

CREATE TABLE AccountUsers ( 
    AccountID INTEGER NOT NULL, 
    Username VARCHAR(15) NOT NULL, 
    PRIMARY KEY (AccountID, Username),
    FOREIGN KEY (AccountID) REFERENCES Accounts(ID)
);  

CREATE TABLE Positions ( 
    AccountID INTEGER, 
    Security VARCHAR(15), 
    Updated TIMESTAMP, 
    Quantity INTEGER, 
    PRIMARY KEY (AccountID, Security),
    FOREIGN KEY (AccountID) REFERENCES Accounts(ID)
);  

CREATE TABLE Trades ( 
    ID VARCHAR(50) PRIMARY KEY, 
    AccountID INTEGER, 
    Created TIMESTAMP, 
    Updated TIMESTAMP, 
    Security VARCHAR(15),  
    Side VARCHAR(10) CHECK (Side IN ('Buy','Sell')),  
    Quantity INTEGER CHECK (Quantity > 0), 
    State VARCHAR(20) CHECK (State IN ('New', 'Processing', 'Settled', 'Cancelled')),
    FOREIGN KEY (AccountID) REFERENCES Accounts(ID)
);  

CREATE SEQUENCE ACCOUNTS_SEQ START WITH 65000 INCREMENT BY 1;

--- SAMPLE DATA ---

INSERT INTO Accounts (ID, DisplayName) VALUES (22214, 'Test Account 20'); 
INSERT INTO Accounts (ID, DisplayName) VALUES (11413, 'Private Clients Fund TTXX'); 
INSERT INTO Accounts (ID, DisplayName) VALUES (42422, 'Algo Execution Partners'); 
INSERT INTO Accounts (ID, DisplayName) VALUES (52355, 'Big Corporate Fund'); 
INSERT INTO Accounts (ID, DisplayName) VALUES (62654, 'Hedge Fund TXY1'); 
INSERT INTO Accounts (ID, DisplayName) VALUES (10031, 'Internal Trading Book'); 
INSERT INTO Accounts (ID, DisplayName) VALUES (44044, 'Trading Account 1'); 

INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user01'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user03'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user09'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user05'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (22214, 'user07'); 

INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user09'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user05'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user07'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (62654, 'user01'); 

INSERT INTO AccountUsers (AccountID, Username) VALUES (10031, 'user01'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (10031, 'user03'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (10031, 'user09'); 

INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user09'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user05'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user07'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user04'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user01'); 
INSERT INTO AccountUsers (AccountID, Username) VALUES (44044, 'user06'); 
 

INSERT INTO Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-22214-AABBCC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'IBM', 'Sell', 100, 'Settled', 22214); 
INSERT INTO Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-22214-DDEEFF', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'MS', 'Buy', 1000, 'Settled', 22214); 
INSERT INTO Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-22214-GGHHII', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'C', 'Sell', 2000, 'Settled', 22214); 

INSERT INTO Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'MS', CURRENT_TIMESTAMP, 1000); 
INSERT INTO Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'IBM', CURRENT_TIMESTAMP, -100); 
INSERT INTO Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'C', CURRENT_TIMESTAMP, -2000); 


INSERT INTO Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-52355-AABBCC', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 'BAC', 'Sell', 2400, 'Settled', 52355); 
INSERT INTO Positions (AccountID, Security, Updated, Quantity) VALUES(52355, 'BAC', CURRENT_TIMESTAMP, -2400); 