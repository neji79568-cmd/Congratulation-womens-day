$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $scriptDir ".site-server.pid"

if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Host "Server is not running."
    exit 0
}

$pidRaw = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
if (-not ($pidRaw -match "^\d+$")) {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    Write-Host "PID file was invalid and has been removed."
    exit 0
}

$serverPid = [int]$pidRaw
$proc = Get-Process -Id $serverPid -ErrorAction SilentlyContinue
if ($proc) {
    Stop-Process -Id $serverPid -Force
    Write-Host "Server stopped (PID $serverPid)."
}
else {
    Write-Host "Server process was not found."
}

Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
