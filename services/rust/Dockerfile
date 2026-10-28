FROM rust:1.82-slim-bookworm AS build
WORKDIR /app
COPY Cargo.toml ./
COPY src ./src
RUN cargo build --release

FROM gcr.io/distroless/cc-debian12:nonroot
LABEL dockerhue.lang=rust
COPY --from=build /app/target/release/hue /hue
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/hue"]
