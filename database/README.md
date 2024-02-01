# FINOS | TraderX Sample Trading App | Database

![DEV Only Warning](https://badgen.net/badge/warning/not-for-production/red) ![Local Dev Machine Supported](http://badgen.net/badge/local-dev/supported/green)

## Introduction

This is designed to play the role of a SQL database that runs standalone as part of an example environment. The other processes in this environment interact with this via SQL / JDBC drivers and therefore this component can be swapped out in other iterations of this environment and replaced with a robust and productionizable RDBMS.

This uses H2 Java-based database as a standalone server, has NO authentication by default, and initializes with an empty SQL schema every time it is started.

## Default Port Numbers
| Protocol | Port Number |
| :--- | :--- |
| TCP | 18082 |
| PG | 18083 |
| HTTP | 18084 |
 
## Connecting to this database remotely
You can use the `$DATABASE_TCP_PORT`  or `$DATABASE_PG_PORT` and the database URL in JDBC is `jdbc:h2:./_data/traderx`

The default username and password are both *sa*

## Connecting to the web console
You can use the `$DATABASE_HTTP_PORT`  or `$DATABASE_PG_PORT` and the database URL in JDBC is `jdbc:h2:traderx` (This is because -baseDir is already set to ./_data) - NOTE you will have to change the default setting in the web console which often uses a home directory path. 

The default username and password are both `sa`

The database you want to use in the H2 GUI is `./traderx` (This may not be the default listed in the GUI)

## Using Web Console behind proxy/K8S/Env
By default, the hostname, localhost, 127.0.0.1 are all valid host headers to access the database. If you wish to connect using another IP, or via some proxy/gateway that's set up through K8S or other environment, you will need to specify the hostname your browser is using to access the web console. This is done by setting the environment variable `$DATABASE_WEB_HOSTNAMES` to the hostname you are using to access the web console. This is a comma-delimited list of fully qualified hostnames.

## Output Directory
Data is stored in the local `./_data` directory from where the script is run. This is .gitignore'd 

## Building

This builds in gradle to retrieve H2.

```shell
$> gradle build
```

## Running on Linux

This is desinged to run on Linux but can easily run on Windows as well. It launches a DB Script runner to pre-populate the database schema- delayed by 20 seconds, and then runs the database server in the foreground.

Currently the run script has environment variables defined for versions of H2 and common ports. These should be altered (or made configurable outside the script) as the environment matures.

To launch, all that should be needed is running:
```shell
$> run.sh
```

## Running from your local Win10 Machine

You CAN run this on windows, with the help of Powershell.  All you need to do is have Java on your path, and then enter bash to run the script.  First launch a Terminal/Command Console in Windows.

```
>bash
>$ . run.sh
```

You will see the following output

```

Runing startup script
Web Console server running at http://[your IP]:18084 (others can connect)
finished startup script
TCP server running at tcp://[your IP]:18082 (others can connect)
PG server running at pg://[your IP]:18083 (others can connect)
```

On my windows PC, it actually doesn't work with the public IP address. Just change the above URLs/Host Addresses to use `localhost`  and they work fine.

Example: http://localhost:18084 

