<#
.SYNOPSIS
  Build (optional) and run the PoCX electrs against a bitcoind node.

.DESCRIPTION
  Sets the LLVM/libclang build environment, then runs ../electrs against a PoCX node.
  Use -SyncOnce for a bounded test (electrs exits after the initial sync).

.PARAMETER Network     bitcoin | testnet | regtest | signet  (default: regtest)
.PARAMETER DaemonDir   bitcoind datadir (for cookie auth). regtest default: testkit/regtest-data
.PARAMETER DbDir       electrs index dir (default: testkit/electrs-db). Isolated + cleanable.
.PARAMETER SyncOnce    Exit after initial sync instead of serving.
.PARAMETER Build       Run `cargo build` first.

.EXAMPLE
  ./run-electrs.ps1 -Network regtest -DaemonDir "$PSScriptRoot/regtest-data" -SyncOnce -Build
  ./run-electrs.ps1 -Network bitcoin -DaemonDir "$env:APPDATA/Bitcoin"   # your main node (needs -rest)
#>
param(
    [ValidateSet("bitcoin", "testnet", "testnet4", "regtest", "signet")]
    [string]$Network   = "regtest",
    [string]$DaemonDir = "$PSScriptRoot\regtest-data",
    [string]$DbDir     = "$PSScriptRoot\electrs-db",
    [switch]$SyncOnce,
    [switch]$Build
)

$ErrorActionPreference = "Stop"
$env:LIBCLANG_PATH = "C:\Program Files\LLVM\bin"
if ($env:PATH -notlike "*LLVM\bin*") { $env:PATH = "C:\Program Files\LLVM\bin;$env:PATH" }

$electrsDir = Resolve-Path "$PSScriptRoot\.."
Push-Location $electrsDir
try {
    if ($Build) {
        Write-Host "Building electrs..." -ForegroundColor Cyan
        cargo build
        if ($LASTEXITCODE -ne 0) { throw "build failed" }
    }
    New-Item -ItemType Directory -Force -Path $DbDir | Out-Null

    $args = @("--network", $Network, "--daemon-dir", $DaemonDir, "--db-dir", $DbDir, "--log-filters", "INFO")
    if ($SyncOnce) { $args += "--sync-once" }

    Write-Host "Running: electrs $($args -join ' ')" -ForegroundColor Cyan
    & ".\target\debug\electrs.exe" @args
} finally {
    Pop-Location
}
