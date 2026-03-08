$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pidFile = Join-Path $scriptDir ".site-server.pid"
$outLogFile = Join-Path $scriptDir ".site-server.out.log"
$errLogFile = Join-Path $scriptDir ".site-server.err.log"
$serverScript = Join-Path $scriptDir "site-server.ps1"
$port = 5500

if (Test-Path -LiteralPath $pidFile) {
    $existingPidRaw = Get-Content -LiteralPath $pidFile -ErrorAction SilentlyContinue
    if ($existingPidRaw -match "^\d+$") {
        $existingPid = [int]$existingPidRaw
        $running = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
        if ($running) {
            Write-Host "Server is already running at http://localhost:$port/ (PID $existingPid)"
            exit 0
        }
    }
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", "`"$serverScript`"",
    "-Port", "$port",
    "-Root", "`"$scriptDir`""
)

if (Test-Path -LiteralPath $outLogFile) {
    Remove-Item -LiteralPath $outLogFile -Force -ErrorAction SilentlyContinue
}
if (Test-Path -LiteralPath $errLogFile) {
    Remove-Item -LiteralPath $errLogFile -Force -ErrorAction SilentlyContinue
}

$process = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WorkingDirectory $scriptDir -PassThru -WindowStyle Hidden -RedirectStandardOutput $outLogFile -RedirectStandardError $errLogFile
$process.Id | Set-Content -LiteralPath $pidFile -Encoding ASCII

Start-Sleep -Milliseconds 700
$running = Get-Process -Id $process.Id -ErrorAction SilentlyContinue
if ($running) {
    Write-Host "Server started at http://localhost:$port/ (PID $($process.Id))"
}
else {
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    Write-Host "Server failed to start. See logs: $outLogFile and $errLogFile"
    if (Test-Path -LiteralPath $outLogFile) {
        Get-Content -LiteralPath $outLogFile
    }
    if (Test-Path -LiteralPath $errLogFile) {
        Get-Content -LiteralPath $errLogFile
    }
}
