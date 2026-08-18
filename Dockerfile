# Important: This file is provided for demonstration purposes and may NOT be suitable for production use.
# The maintainers of electrs are not deeply familiar with Docker, so you should DYOR.
# If you are not familiar with Docker either it's probably be safer to NOT use it.

FROM debian:trixie-slim AS base
RUN apt-get update -qqy
RUN apt-get install -qqy librocksdb-dev curl git

### Electrum Rust Server ###
FROM base AS electrs-build
RUN apt-get install -qqy cargo build-essential libclang-dev

# Install electrs
WORKDIR /build
# Clone bindex-btcx side-by-side as required by the path dependency in Cargo.toml
RUN git clone https://github.com/PoC-Consortium/bindex-btcx.git /build/bindex-btcx

WORKDIR /build/electrs
COPY . .
ENV ROCKSDB_INCLUDE_DIR=/usr/include
ENV ROCKSDB_LIB_DIR=/usr/lib
RUN cargo install --locked --path .

FROM base AS result
# Copy the binaries
COPY --from=electrs-build /root/.cargo/bin/electrs /usr/bin/electrs

WORKDIR /
