#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${ROOT}/codebase/generated-components/database-specfirst"
GRADLE_WRAPPER_TEMPLATE="${ROOT}/templates/gradle-wrapper"

rm -rf "${TARGET}"
mkdir -p "${TARGET}/gradle/wrapper"

cat <<'EOF' > "${TARGET}/README.md"
# Database (Spec-First Generated)

This component is generated from TraderSpec database component requirements.

## Run

```bash
./gradlew build
./run.sh
```

## Default Ports

- TCP: `18082`
- PG: `18083`
- Web: `18084`
EOF

cat <<'EOF' > "${TARGET}/.gitignore"
_data/
build/
.gradle/
EOF

cat <<'EOF' > "${TARGET}/settings.gradle"
dependencyResolutionManagement {
  repositories {
    mavenCentral()
  }
}

rootProject.name = 'database-specfirst'
EOF

cat <<'EOF' > "${TARGET}/build.gradle"
plugins {
  id 'application'
}

dependencies {
  implementation 'com.h2database:h2:2.3.232'
}

application {
  mainClass = 'org.h2.tools.Console'
}

jar {
  manifest {
    attributes "Main-Class": "org.h2.tools.Console"
  }

  from {
    configurations.runtimeClasspath.collect { it.isDirectory() ? it : zipTree(it) }
  }
}
EOF

cat <<'EOF' > "${TARGET}/run.sh"
#!/usr/bin/env bash
set -euo pipefail

set -a
: "${DATABASE_TCP_PORT:=18082}"
: "${DATABASE_PG_PORT:=18083}"
: "${DATABASE_WEB_PORT:=18084}"
: "${DATABASE_DBUSER:=sa}"
: "${DATABASE_DBPASS:=sa}"
: "${DATABASE_H2JAR:=./build/libs/database-specfirst.jar}"
: "${DATABASE_DATA_DIR:=./_data}"
: "${DATABASE_DBNAME:=traderx}"
: "${DATABASE_HOSTNAME:=${HOSTNAME:-localhost}}"
: "${DATABASE_JDBC_URL:=jdbc:h2:tcp://$DATABASE_HOSTNAME:$DATABASE_TCP_PORT/$DATABASE_DBNAME}"
: "${DATABASE_WEB_HOSTNAMES:=${DATABASE_HOSTNAME}}"
set +a

echo "Data will be located in ${DATABASE_DATA_DIR}"
echo "Database name is ${DATABASE_DBNAME}"
echo "Running schema setup script"
echo "---------------------------------------------------------------------------"

java -cp "${DATABASE_H2JAR}" org.h2.tools.RunScript \
  -url "jdbc:h2:${DATABASE_DATA_DIR}/${DATABASE_DBNAME};DATABASE_TO_UPPER=TRUE;TRACE_LEVEL_SYSTEM_OUT=3" \
  -user "${DATABASE_DBUSER}" \
  -password "${DATABASE_DBPASS}" \
  -script initialSchema.sql

echo "Starting Database Server"
echo "---------------------------------------------------------------------------"

exec java -jar "${DATABASE_H2JAR}" \
  -pg -pgPort "${DATABASE_PG_PORT}" -pgAllowOthers -baseDir "${DATABASE_DATA_DIR}" \
  -tcp -tcpPort "${DATABASE_TCP_PORT}" -tcpAllowOthers \
  -web -webPort "${DATABASE_WEB_PORT}" -webExternalNames "${DATABASE_WEB_HOSTNAMES}" -webAllowOthers
EOF

cat <<'EOF' > "${TARGET}/initialSchema.sql"
Drop Table Trades IF EXISTS;
Drop Table AccountUsers IF EXISTS;
Drop Table Positions IF EXISTS;
Drop Table Accounts IF EXISTS;
Drop Sequence ACCOUNTS_SEQ IF EXISTS;

CREATE TABLE Accounts ( ID INTEGER PRIMARY KEY, DisplayName VARCHAR (50) );
CREATE TABLE AccountUsers ( AccountID INTEGER NOT NULL, Username VARCHAR(15) NOT NULL, PRIMARY KEY (AccountID,Username));
ALTER TABLE AccountUsers ADD FOREIGN KEY (AccountID) References Accounts(ID);

CREATE TABLE Positions ( AccountID INTEGER, Security VARCHAR(15), Updated TIMESTAMP, Quantity INTEGER, Primary Key (AccountID, Security) );
Alter Table Positions ADD FOREIGN KEY (AccountID) References Accounts(ID);

CREATE TABLE Trades (
  ID Varchar (50) Primary Key,
  AccountID INTEGER,
  Created TIMESTAMP,
  Updated TIMESTAMP,
  Security VARCHAR (15),
  Side VARCHAR(10) check (Side in ('Buy','Sell')),
  Quantity INTEGER check Quantity > 0,
  State VARCHAR(20) check (State in ('New', 'Processing', 'Settled', 'Cancelled'))
);
Alter Table Trades Add Foreign Key (AccountID) references Accounts(ID);

CREATE SEQUENCE ACCOUNTS_SEQ start with 65000 INCREMENT BY 1;

INSERT into Accounts (ID, DisplayName) VALUES (22214, 'Test Account 20');
INSERT into Accounts (ID, DisplayName) VALUES (11413, 'Private Clients Fund TTXX');
INSERT into Accounts (ID, DisplayName) VALUES (42422, 'Algo Execution Partners');
INSERT into Accounts (ID, DisplayName) VALUES (52355, 'Big Corporate Fund');
INSERT into Accounts (ID, DisplayName) VALUES (62654, 'Hedge Fund TXY1');
INSERT into Accounts (ID, DisplayName) VALUES (10031, 'Internal Trading Book');
INSERT into Accounts (ID, DisplayName) VALUES (44044, 'Trading Account 1');

INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'user01');
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'user03');
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'user09');
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'user05');
INSERT into AccountUsers (AccountID, Username) VALUES (22214, 'user07');
INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'user09');
INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'user05');
INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'user07');
INSERT into AccountUsers (AccountID, Username) VALUES (62654, 'user01');
INSERT into AccountUsers (AccountID, Username) VALUES (10031, 'user01');
INSERT into AccountUsers (AccountID, Username) VALUES (10031, 'user03');
INSERT into AccountUsers (AccountID, Username) VALUES (10031, 'user09');
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'user09');
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'user05');
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'user07');
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'user04');
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'user01');
INSERT into AccountUsers (AccountID, Username) VALUES (44044, 'user06');

INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-22214-AABBCC', NOW(), NOW(), 'IBM', 'Sell', 100, 'Settled', 22214);
INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-22214-DDEEFF', NOW(), NOW(), 'MS', 'Buy', 1000, 'Settled', 22214);
INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-22214-GGHHII', NOW(), NOW(), 'C', 'Sell', 2000, 'Settled', 22214);

INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'MS',NOW(), 1000);
INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'IBM',NOW(), -100);
INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(22214, 'C',NOW(), -2000);

INSERT into Trades(ID, Created, Updated, Security, Side, Quantity, State, AccountID) VALUES('TRADE-52355-AABBCC', NOW(), NOW(), 'BAC', 'Sell', 2400, 'Settled', 52355);
INSERT into Positions (AccountID, Security, Updated, Quantity) VALUES(52355, 'BAC',NOW(), -2400);
EOF

cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew" "${TARGET}/gradlew"
cp "${GRADLE_WRAPPER_TEMPLATE}/gradlew.bat" "${TARGET}/gradlew.bat"
cp -R "${GRADLE_WRAPPER_TEMPLATE}/gradle/wrapper/"* "${TARGET}/gradle/wrapper/"
chmod +x "${TARGET}/gradlew" "${TARGET}/run.sh"

echo "[done] regenerated ${TARGET}"
