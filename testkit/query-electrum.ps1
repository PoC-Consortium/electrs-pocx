<#
.SYNOPSIS
  Send a single Electrum-protocol JSON-RPC request to a running electrs.

.DESCRIPTION
  The Electrum protocol is newline-delimited JSON-RPC over TCP.
  Default port: 60401 (regtest), 50001 (mainnet), 60001 (testnet), 60601 (signet).

.EXAMPLE
  ./query-electrum.ps1                                              # server.version
  ./query-electrum.ps1 -Method blockchain.headers.subscribe
  ./query-electrum.ps1 -Method blockchain.scripthash.get_balance -Params @("<scripthash-hex>")
  ./query-electrum.ps1 -Addr 127.0.0.1:50001 -Method server.banner

.NOTE
  A scripthash is sha256(scriptPubkey) with bytes reversed - see the Electrum protocol docs.
#>
param(
    [string]$Addr = "127.0.0.1:60401",
    [string]$Method = "server.version",
    [object[]]$Params = @("pocx-testkit", "1.4")
)

$ErrorActionPreference = "Stop"
$parts = $Addr.Split(":")
$node = $parts[0]; $port = [int]$parts[1]

$req = @{ jsonrpc = "2.0"; id = 0; method = $Method; params = $Params } | ConvertTo-Json -Compress
Write-Host "-> $req" -ForegroundColor DarkGray

$client = [System.Net.Sockets.TcpClient]::new()
try {
    $client.Connect($node, $port)
    $stream = $client.GetStream()
    $writer = [System.IO.StreamWriter]::new($stream); $writer.NewLine = "`n"; $writer.AutoFlush = $true
    $reader = [System.IO.StreamReader]::new($stream)
    $writer.WriteLine($req)
    $line = $reader.ReadLine()
    Write-Host "<- $line" -ForegroundColor Green
} catch {
    Write-Host "FAIL: could not query $Addr - is electrs serving? ($($_.Exception.Message))" -ForegroundColor Red
    exit 1
} finally {
    $client.Close()
}
