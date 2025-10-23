# Use PostgreSQL official image
FROM postgres:16

# Set environment variables with defaults
ENV POSTGRES_DB=traderx
ENV POSTGRES_USER=sa
ENV POSTGRES_PASSWORD=sa
ENV PGDATA=/var/lib/postgresql/data/pgdata

# Copy initialization script
COPY initialSchema.sql /docker-entrypoint-initdb.d/

# Expose PostgreSQL port
EXPOSE 5432

# Use the default PostgreSQL entrypoint 