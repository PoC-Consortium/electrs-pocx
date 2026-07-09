# testkit — validating BTCX electrs

Scaffolding to test the BTCX `electrs` + `bindex-btcx` stack against a Bitcoin PoCX node.
Two paths: an **isolated regtest node**, or **your existing node** once it has `-rest` enabled.
Nothing here touches a node you don't point it at.

## Prerequisites
- A **Bitcoin PoCX (`ENABLE_POCX`) bitcoind** build. The stock Bitcoin Core install will *not* produce
  286-byte Bitcoin PoCX headers — `check-node.ps1` will tell you which you have.
- The node must run with the **REST interface**: `-rest` (and `server=1`). bindex talks to bitcoind
  over REST only.
- Build toolchain (already set up): LLVM/libclang at `C:\Program Files\LLVM\bin`. The run script
  sets `LIBCLANG_PATH`/`PATH` for you.

## Scripts
| Script | Purpose |
|--------|---------|
| `check-node.ps1` | Validate a node's REST: 286-byte headers + block hash == `SHA256d(header, signature zeroed)` + `/rest/spenttxouts` present. **The core correctness check.** |
| `regtest-up.ps1` | Start an isolated BTCX regtest node with `-rest` in `testkit/regtest-data`. |
| `run-electrs.ps1` | Build (optional) and run `../electrs` against a node; `-SyncOnce` for a bounded test. |
| `query-electrum.ps1` | Send one Electrum-protocol JSON-RPC request to a running electrs. |

## Path A — isolated regtest
```powershell
cd testkit
./regtest-up.ps1 -Bitcoind "C:\Program Files\Bitcoin\daemon\bitcoind.exe" -Mine 101
./check-node.ps1 -RpcUrl http://127.0.0.1:18443           # expect: PASS, PoCX(286)
./run-electrs.ps1 -Network regtest -DaemonDir "$PWD/regtest-data" -SyncOnce -Build
# then, if serving (drop -SyncOnce):
./query-electrum.ps1 -Addr 127.0.0.1:60401 -Method server.version
```
Note: BTCX regtest mining may not use stock `generatetoaddress`; if `-Mine` warns, generate blocks
with your BTCX tooling, then re-run `check-node.ps1`.

## Path B — your existing node (once `-rest` is on)
Add `rest=1` (and `server=1`) to your `bitcoin.conf`, restart, then:
```powershell
cd testkit
./check-node.ps1 -RpcUrl http://127.0.0.1:8332
./run-electrs.ps1 -Network bitcoin -DaemonDir "$env:APPDATA/Bitcoin" -SyncOnce
./query-electrum.ps1 -Addr 127.0.0.1:50001 -Method server.version
```

## What "success" looks like
1. `check-node.ps1` → **PASS**: headers are 286 bytes and every sampled block hash matches the
   signature-zeroed double-SHA256 rule. This proves bindex will compute the node's block hashes.
2. `run-electrs.ps1 -SyncOnce` → syncs to the tip and exits 0 (indexes blocks without parse errors).
3. `query-electrum.ps1` → electrs answers `server.version`; a `blockchain.scripthash.get_balance`
   for a funded scripthash returns the right balance.

Generated `regtest-data/` and `electrs-db/` are gitignored and safe to delete between runs.
