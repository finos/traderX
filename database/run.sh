#!/bin/bash

# This script is no longer used as the database service now uses PostgreSQL
# directly via the official PostgreSQL Docker image.
# 
# PostgreSQL is started automatically by the postgres:16 base image.
# The initialSchema.sql script is automatically executed on first startup
# via the /docker-entrypoint-initdb.d/ mechanism.
#
# Connection details:
# - Host: database (service name in docker-compose)
# - Port: 5432 (standard PostgreSQL port)
# - Database: traderx
# - Username: sa
# - Password: sa
# - JDBC URL: jdbc:postgresql://database:5432/traderx

echo "This script is deprecated. PostgreSQL starts automatically via the Docker entrypoint."