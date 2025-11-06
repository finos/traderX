# Multi-stage build for database service
FROM eclipse-temurin:21-jdk-jammy AS builder

WORKDIR /database
COPY . .
RUN ./gradlew build --no-daemon

# Runtime stage with minimal JRE
FROM eclipse-temurin:21-jre-jammy

WORKDIR /database

# Copy only the built artifacts and necessary files
COPY --from=builder /database/build ./build
COPY --from=builder /database/run.sh ./run.sh
COPY --from=builder /database/initialSchema.sql ./initialSchema.sql

# Convert Windows line endings to Unix and make run script executable
RUN sed -i 's/\r$//' ./run.sh && chmod +x ./run.sh

EXPOSE 18082 18083 18084

ENTRYPOINT ["./run.sh"]
