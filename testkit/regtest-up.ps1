<#
.SYNOPSIS
  Start an isolated PoCX bitcoind in regtest with the REST interface enabled.

.DESCRIPTION
  Uses a dedicated datadir under testkit/ so it never touches your live node.
  Requires a PoCX (ENABLE_POCX) bitcoind build. After it's up, validate with
  ./check-node.ps1 -RpcUrl http://127.0.0.1:18443 and run electrs with ./run-electrs.ps1.

.PARAMETER Bitcoind
  Path to the PoCX bitcoind.exe (must be the ENABLE_POCX build).

.PARAMETER DataDir
  Regtest datadir (created if missing). Default: testkit/regtest-data.

.PARAMETER Mine
  Best-effort: blocks to generate after startup (PoCX regtest mining may differ from
  stock `generatetoaddress`; a failure here is reported, not fatal).

.EXAMPLE
  ./regtest-up.ps1 -Bitcoind "C:\Program Files\Bitcoin\daemon\bitcoind.exe" -Mine 101
#>
param(
    [string]$Bitcoind = "C:\Program Files\Bitcoin\daemon\bitcoind.exe",
    [string]$DataDir  = "$PSScriptRoot\regtest-data",
    [int]$Mine        = 0
)

$ErrorActionPreference = "Stop"
$Cli = Join-Path (Split-Path $Bitcoind) "bitcoin-cli.exe"
if (-not (Test-Path $Bitcoind)) { throw "bitcoind not found: $Bitcoind (pass -Bitcoind <path to PoCX build>)" }
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

$common = @("-regtest", "-datadir=$DataDir")
Write-Host "Starting PoCX bitcoind (regtest, REST) in $DataDir ..." -ForegroundColor Cyan
Start-Process -FilePath $Bitcoind -ArgumentList ($common + @(
        "-server", "-rest", "-fallbackfee=0.0001", "-rpcbind=127.0.0.1", "-rpcallowip=127.0.0.1"
    )) -WindowStyle Hidden

# Wait for RPC readiness (cookie-authenticated via -datadir).
$ready = $false
foreach ($i in 1..30) {
    Start-Sleep -Seconds 1
    try { & $Cli @common getblockchaininfo | Out-Null; if ($?) { $ready = $true; break } } catch {}
}
if (-not $ready) { throw "bitcoind did not become ready - check $DataDir\regtest\debug.log" }
Write-Host "bitcoind ready. REST at http://127.0.0.1:18443" -ForegroundColor Green

if ($Mine -gt 0) {
    try {
        $addr = (& $Cli @common getnewaddress) 2>$null
        & $Cli @common generatetoaddress $Mine $addr | Out-Null
        Write-Host "Mined $Mine blocks to $addr" -ForegroundColor Green
    } catch {
        Write-Host "NOTE: `generatetoaddress` failed - PoCX regtest likely mines differently. Mine via your PoCX tooling, then re-run check-node.ps1." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "  ./check-node.ps1 -RpcUrl http://127.0.0.1:18443"
Write-Host "  ./run-electrs.ps1 -Network regtest -DaemonDir `"$DataDir`""
Write-Host "Stop the node with:  & `"$Cli`" -regtest -datadir=`"$DataDir`" stop"
