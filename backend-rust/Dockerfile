FROM rust:latest AS builder
WORKDIR /app

# Copy the entire workspace to include backend-rust and packages/uwb-types
COPY . .

WORKDIR /app/backend-rust
RUN cargo build --release

# Final runtime stage
FROM debian:bullseye-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# The output is placed in the workspace root's target folder
COPY --from=builder /app/target/release/regatta-backend /app/regatta-backend

RUN mkdir -p /data
ENV BACKEND_MODE=cloud
ENV PORT=3001
ENV BINDADDR=0.0.0.0

# Ensure binary is executable
RUN chmod +x /app/regatta-backend
EXPOSE 3001 5555/udp

CMD ["/app/regatta-backend"]
