# electrs-btcx — Electrum server for BTCX

BTCX (Bitcoin-PoCX) port of [romanz/electrs](https://github.com/romanz/electrs) (branch `btcx`, from
upstream `31c3fc5`): an Electrum-protocol server for BTCX, targeting nodeless wallets and swap trading.

> Looking for the **block-explorer** backend (Esplora REST API)? That is a different fork of a
> different electrs: [PoC-Consortium/esplora-electrs-pocx](https://github.com/PoC-Consortium/esplora-electrs-pocx)
> (based on blockstream/electrs), which powers
> [esplora-pocx](https://github.com/PoC-Consortium/esplora-pocx).

## How the port works

Upstream electrs delegates all chain indexing to the external
[`bindex`](https://github.com/romanz/bindex-rs) crate, which talks to bitcoind over the **REST
interface only** (no `blk*.dat`, no P2P). The PoCX consensus difference — a **286-byte block
header** (vs 80) whose hash is computed with the 65-byte signature zeroed — therefore lives almost
entirely in the bindex fork:
[PoC-Consortium/bindex-pocx](https://github.com/PoC-Consortium/bindex-pocx)
(see its `PORT-PLAN.md` for the full change list).

This repo's own diff vs upstream is two lines of intent:
- `Cargo.toml`: the `bindex` dependency points at `../bindex-pocx/bindex-lib` (path dependency).
- `src/config.rs`: the testnet datadir subdirectory is `testnet` (bitcoin-pocx) instead of `testnet3`.

## Building

Clone the two repos **side by side** (the path dependency requires it):

```
git clone https://github.com/PoC-Consortium/bindex-pocx
git clone https://github.com/PoC-Consortium/electrs-btcx
cd electrs-btcx && cargo build --release
```

- **Linux**: standard electrs prerequisites (librocksdb via the bundled build works out of the box).
- **Windows (MSVC)**: install [LLVM](https://releases.llvm.org/) and set
  `LIBCLANG_PATH=C:\Program Files\LLVM\bin` (rust-rocksdb's bindgen needs libclang).
  `testkit/run-electrs.ps1` sets this automatically.

## Node requirements

- Bitcoin-PoCX Core **v31+** with the REST interface enabled (`-rest` or `rest=1` in bitcoin.conf).
  bindex needs `/rest/spenttxouts` (30.0+) and `/rest/blockpart` (31.0+).
- REST is served unauthenticated on the RPC port (default :8332) — keep it bound to localhost.
- The RPC `.cookie` file is used for auth; point `--daemon-dir` at the node's datadir.

```
electrs --network bitcoin --daemon-dir <datadir> --db-dir <index-dir>
```

## testkit/

PowerShell scaffolding to validate the stack against a BTCX node (see `testkit/README.md`):

| Script | Purpose |
|---|---|
| `check-node.ps1` | Validates a node's REST: 286-byte headers, block hash == SHA256d(header with signature zeroed), `/rest/spenttxouts` present. |
| `run-electrs.ps1` | Build + run electrs against a node (`-SyncOnce` for a bounded test). |
| `query-electrum.ps1` | Send a single Electrum JSON-RPC request (scripthash balance/history, headers, raw tx). |
| `regtest-up.ps1` | Spin up an isolated BTCX regtest node with REST. |

Validated 2026-07-03 against BTCX mainnet (44k+ blocks): full sync, header/scripthash/transaction
queries all correct.

## Wallet-client notes

Electrum clients connecting to this server must be PoCX-aware: parse 286-byte headers, skip
PoW/SPV difficulty checks, and know the BTCX genesis hash and the `pocx` bech32 HRP.
Upstream limitation inherited from romanz/electrs: no `cp_height` header-checkpoint merkle proofs.
