FROM rust:1.98-bookworm AS build
WORKDIR /src
COPY Cargo.toml Cargo.lock build.rs ./
COPY migrations migrations
COPY src src
RUN cargo build --release --locked

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=build /src/target/release/feswave /usr/local/bin/feswave
ENV HOST=0.0.0.0 PORT=8080
USER 65532:65532
ENTRYPOINT ["/usr/local/bin/feswave"]
