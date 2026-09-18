# Launches MSIX-packaged TradingView Desktop with CDP enabled, via COM activation
# (IApplicationActivationManager) instead of a raw exe launch.
#
# Use this when scripts\launch_tv_debug.bat / the tv_launch MCP tool fail with the
# app exiting immediately after launch -- that happens because current TradingView
# Desktop builds (Store and direct-download alike) are MSIX-packaged, and MSIX
# enforces package identity: copying/launching the exe outside its package context
# makes it exit right away instead of opening a window. This script instead activates
# the package the way Explorer/Start Menu do, which preserves identity while still
# passing the debug-port flag through. No Developer Mode or admin rights needed.
#
# Usage: scripts\launch_tv_debug_msix.ps1 [port]

param(
    [int]$Port = 9222
)

$pkg = Get-AppxPackage -Name "*TradingView*" | Select-Object -First 1
if (-not $pkg) {
    Write-Error "No TradingView AppX package found. Is TradingView Desktop installed?"
    exit 1
}

[xml]$manifest = Get-Content (Join-Path $pkg.InstallLocation "AppxManifest.xml")
$appId = $manifest.Package.Applications.Application.Id
$aumid = "$($pkg.PackageFamilyName)!$appId"
Write-Host "Found package: $($pkg.PackageFullName)"
Write-Host "AUMID: $aumid"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cacheDir = Join-Path $env:LOCALAPPDATA "tradingview-mcp\bin"
$exePath = Join-Path $cacheDir "LaunchTvMsix.exe"
$srcPath = Join-Path $scriptDir "LaunchTvMsix.cs"

if (-not (Test-Path $exePath) -or (Get-Item $srcPath).LastWriteTime -gt (Get-Item $exePath).LastWriteTime) {
    Write-Host "Compiling launch helper..."
    New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
    $cscDir = [System.Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()
    $csc = Join-Path $cscDir "csc.exe"
    if (-not (Test-Path $csc)) {
        Write-Error "csc.exe not found at $csc (.NET Framework required)"
        exit 1
    }
    & $csc /nologo /out:$exePath $srcPath
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compilation failed"
        exit 1
    }
}

& $exePath $aumid "--remote-debugging-port=$Port"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Waiting for CDP to become available on port $Port..."
for ($i = 0; $i -lt 15; $i++) {
    Start-Sleep -Seconds 1
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 2
        Write-Host "CDP ready:"
        Write-Host $r.Content
        exit 0
    } catch { }
}
Write-Error "CDP did not become available within 15s"
exit 1
