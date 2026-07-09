<#
.SYNOPSIS
  Validate that a PoCX bitcoind's REST interface is compatible with bindex-btcx.

.DESCRIPTION
  Checks, against a running node's REST interface (requires `-rest`):
    1. /rest/chaininfo.json is reachable.
    2. Block headers are 286 bytes (PoCX format) - not 80 (stock Bitcoin).
    3. The block hash equals SHA256d(header with the 65-byte signature zeroed) -
       i.e. the exact rule bindex-btcx's PoCXBlockHeader::block_hash() implements.
    4. /rest/spenttxouts/<hash>.bin exists (bindex requires it; Core 30.0+).

  This is the key offline-ish correctness check: if hashes match here, bindex will
  compute the same block hashes the node does and sync correctly.

.EXAMPLE
  ./check-node.ps1                              # defaults to mainnet REST on :8332
  ./check-node.ps1 -RpcUrl http://127.0.0.1:18443   # regtest
#>
param(
    [string]$RpcUrl = "http://127.0.0.1:8332"
)

$ErrorActionPreference = "Stop"
$RpcUrl = $RpcUrl.TrimEnd("/")

function Get-Bytes($url) { (Invoke-WebRequest -UseBasicParsing -Uri $url).RawContentStream.ToArray() }
function Get-Text($url)  { (Invoke-WebRequest -UseBasicParsing -Uri $url).Content.Trim() }

Write-Host "=== PoCX node REST check: $RpcUrl ===" -ForegroundColor Cyan

try {
    $info = Invoke-RestMethod "$RpcUrl/rest/chaininfo.json"
} catch {
    Write-Host "FAIL: REST not reachable at $RpcUrl/rest/chaininfo.json" -ForegroundColor Red
    Write-Host "      Enable it with `-rest` (and `server=1`) on bitcoind, then retry." -ForegroundColor Yellow
    exit 1
}
$tip = [int]$info.blocks
Write-Host ("chain={0}  blocks={1}  bestblockhash={2}" -f $info.chain, $tip, $info.bestblockhash)

$sha = [System.Security.Cryptography.SHA256]::Create()
$heights = @(0, 1, $tip) | Sort-Object -Unique | Where-Object { $_ -le $tip -and $_ -ge 0 }
$allOk = $true
$sawPocx = $false

foreach ($h in $heights) {
    $hashHex = Get-Text "$RpcUrl/rest/blockhashbyheight/$h.hex"
    $hdr = Get-Bytes "$RpcUrl/rest/headers/1/$hashHex.bin"
    $size = $hdr.Length

    $mod = [byte[]]::new($size)
    [Array]::Copy($hdr, $mod, $size)
    $kind = ""
    if ($size -eq 286) {
        $sawPocx = $true
        $kind = "PoCX(286)"
        for ($i = $size - 65; $i -lt $size; $i++) { $mod[$i] = 0 }  # zero signature
    } elseif ($size -eq 80) {
        $kind = "stock(80)"   # standard Bitcoin header: hashed as-is
    } else {
        $kind = "size=$size"
    }

    $d = $sha.ComputeHash($sha.ComputeHash($mod))
    [Array]::Reverse($d)                       # internal LE -> display hex
    $calc = -join ($d | ForEach-Object { $_.ToString("x2") })

    $ok = ($calc -eq $hashHex)
    $allOk = $allOk -and $ok
    $mark = if ($ok) { "OK " } else { "BAD" }
    $color = if ($ok) { "Green" } else { "Red" }
    Write-Host ("[{0}] h={1,-7} {2,-10} hash={3}" -f $mark, $h, $kind, $hashHex) -ForegroundColor $color
    if (-not $ok) { Write-Host ("       computed={0}" -f $calc) -ForegroundColor Red }
}

# spenttxouts endpoint (bindex requires it)
try {
    $null = Get-Bytes "$RpcUrl/rest/spenttxouts/$($info.bestblockhash).bin"
    Write-Host "[OK ] /rest/spenttxouts present" -ForegroundColor Green
} catch {
    Write-Host "[BAD] /rest/spenttxouts missing - need Bitcoin Core 30.0+" -ForegroundColor Red
    $allOk = $false
}

Write-Host ""
if (-not $sawPocx) {
    Write-Host "WARNING: no 286-byte headers seen - this looks like a STOCK Bitcoin node, not PoCX." -ForegroundColor Yellow
}
if ($allOk -and $sawPocx) {
    Write-Host "RESULT: PASS - PoCX REST is compatible; block hashes match bindex's rule." -ForegroundColor Green
    exit 0
} else {
    Write-Host "RESULT: FAIL - see red lines above." -ForegroundColor Red
    exit 1
}
