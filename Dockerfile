# syntax=docker/dockerfile:1

# ---- Build stage -----------------------------------------------------------
# Edition 2024 plus the dependencies (let-chains, Duration::from_mins) need a
# recent stable toolchain, so track the latest stable instead of pinning old.
FROM rust:1-bookworm AS builder

# git: several dependencies are fetched from GitHub (authz, authnz, blogs,
# s3-upload, notification). pkg-config/libssl-dev: in case a transitive crate
# links OpenSSL; harmless if none does.
RUN apt-get update \
    && apt-get install -y --no-install-recommends git pkg-config libssl-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Build dependencies first against a stub main, so this slow layer is cached
# until Cargo.toml / Cargo.lock change.
COPY Cargo.toml Cargo.lock* ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo build --release \
    && rm -rf src target/release/deps/ferum* target/release/ferum*

COPY src ./src
RUN cargo build --release

# ---- Runtime stage ---------------------------------------------------------
FROM debian:bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates libssl3 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --uid 10001 ferum

WORKDIR /home/ferum
COPY --from=builder /app/target/release/ferum /usr/local/bin/ferum

USER ferum

# The gateway port the frontend proxies to (GATEWAY_URL, default 8080).
EXPOSE 8080

# Configuration (database, session/auth secrets, email provider, S3, the
# *_SUBJECTS allow-lists, ...) comes from the environment: pass it with
# `--env-file .env` or your orchestrator. main.rs also loads a `.env` from the
# working directory if one is present.
CMD ["ferum"]
