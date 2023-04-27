Drop Table Trades IF EXISTS;

Drop Table AccountUsers IF EXISTS; 

Drop Table Positions IF EXISTS; 

Drop Table Accounts IF EXISTS; 

CREATE TABLE Accounts ( ID INTEGER PRIMARY KEY, DisplayName VARCHAR (50) ) ; 

CREATE TABLE AccountUsers ( AccountID INTEGER NOT NULL, Username VARCHAR(15) NOT NULL, PRIMARY KEY (AccountID,Username));  

ALTER TABLE AccountUsers ADD FOREIGN KEY (AccountID) References Accounts(ID); 

CREATE TABLE Positions ( AccountID INTEGER , Security VARCHAR(15) , Updated TIMESTAMP, Quantity INTEGER, Primary Key (AccountID, Security) );  

Alter Table Positions ADD FOREIGN KEY (AccountID) References Accounts(ID) ; 

CREATE TABLE Trades ( ID Varchar (50) Primary Key, AccountID INTEGER, Created TIMESTAMP, Updated TIMESTAMP, Security VARCHAR (15) ,  Side VARCHAR(10) check (side in ('Buy','Sell')),  Quantity INTEGER check quantity > 0 , State VARCHAR(20) check (State in ('New', 'Processing', 'Settled', 'Cancelled'))) ;  

Alter Table Trades Add Foreign Key (AccountID) references Accounts(ID); 


--- SAMPLE DATA ---

INSERT into Accounts (ID, DisplayName) VALUES (22214, 'Test Account 20'); 
INSERT into Accounts (ID, DisplayName) VALUES (11413, 'Private Clients Fund TTXX'); 
INSERT into Accounts (ID, DisplayName) VALUES (42422, 'Algo Execution Partners'); 
INSERT into Accounts (ID, DisplayName) VALUES (52355, 'Big Corporate Fund'); 
INSERT into Accounts (ID, DisplayName) VALUES (62654, 'Hedge Fund TXY1'); 
INSERT into Accounts (ID, DisplayName) VALUES (10031, 'Internal Trading Book'); 
INSERT into Accounts (ID, DisplayName) VALUES (44044, 'Trading Account 1'); 

INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'john'); 
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'steve'); 
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'jane'); 
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'stacy'); 
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'julia'); 

INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'jane'); 
INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'stacy'); 
INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'julia'); 
INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'john'); 

INSERT into AccountUsers (AccountID, Username) VALUES (10031, 'john'); 
INSERT into AccountUsers (AccountID, Username) VALUES (10031, 'steve'); 
INSERT into AccountUsers (AccountID, Username) VALUES (10031, 'jane'); 

INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'jane'); 
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'stacy'); 
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'julia'); 
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'dave'); 
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'john'); 
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'brian'); 
 

INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, accountID) VALUES('TRADE-22214-AABBCC', NOW(), NOW(), 'IBM', 'Sell', 100, 'Settled', 22214); 
INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, accountID) VALUES('TRADE-22214-DDEEFF', NOW(), NOW(), 'MS', 'Buy', 1000, 'Settled', 22214); 
INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, accountID) VALUES('TRADE-22214-GGHHII', NOW(), NOW(), 'C', 'Sell', 2000, 'Settled', 22214); 

INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'MS',NOW(), 1000); 
INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'IBM',NOW(), -100); 
INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'C',NOW(), -2000); 


INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, accountID) VALUES('TRADE-52355-AABBCC', NOW(), NOW(), 'BAC', 'Sell', 2400, 'Settled', 52355); 
INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(52355, 'BAC',NOW(), -2400); 