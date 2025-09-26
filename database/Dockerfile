# PostgreSQL database service
FROM postgres:15-alpine

# Copy initialization script to be run by PostgreSQL
COPY initialSchema.sql /docker-entrypoint-initdb.d/01-init.sql

# Expose PostgreSQL port
EXPOSE 5432
