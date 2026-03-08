param(
    [int]$Port = 5500,
    [string]$Root = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rootPath = [System.IO.Path]::GetFullPath($Root)
$rootPrefix = $rootPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".htm"  = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".webp" = "image/webp"
    ".ico"  = "image/x-icon"
}

function Send-BytesResponse {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.Sockets.NetworkStream]$Stream,
        [Parameter(Mandatory = $true)]
        [int]$StatusCode,
        [Parameter(Mandatory = $true)]
        [string]$StatusText,
        [Parameter(Mandatory = $true)]
        [byte[]]$BodyBytes,
        [Parameter(Mandatory = $true)]
        [string]$ContentType
    )

    $headers = "HTTP/1.1 $StatusCode $StatusText`r`n" +
        "Connection: close`r`n" +
        "Content-Type: $ContentType`r`n" +
        "Content-Length: $($BodyBytes.Length)`r`n" +
        "`r`n"

    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($BodyBytes.Length -gt 0) {
        $Stream.Write($BodyBytes, 0, $BodyBytes.Length)
    }
}

function Send-TextResponse {
    param(
        [Parameter(Mandatory = $true)]
        [System.Net.Sockets.NetworkStream]$Stream,
        [Parameter(Mandatory = $true)]
        [int]$StatusCode,
        [Parameter(Mandatory = $true)]
        [string]$StatusText
    )

    $body = [System.Text.Encoding]::UTF8.GetBytes($StatusText)
    Send-BytesResponse -Stream $Stream -StatusCode $StatusCode -StatusText $StatusText -BodyBytes $body -ContentType "text/plain; charset=utf-8"
}

function Resolve-RequestPath {
    param([string]$RawPath)

    $pathOnly = ($RawPath -split '\?')[0]
    $relativePath = [System.Uri]::UnescapeDataString($pathOnly.TrimStart('/'))
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
        $relativePath = "index.html"
    }
    return $relativePath
}

try {
    $listener.Start()
    Write-Host "Serving $rootPath on http://localhost:$Port/"

    while ($true) {
        $client = $null
        try {
            $client = $listener.AcceptTcpClient()
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 1024, $true)

            $requestLine = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($requestLine)) {
                continue
            }

            while (($line = $reader.ReadLine()) -ne $null -and $line -ne "") {
            }

            $parts = $requestLine.Split(' ')
            if ($parts.Length -lt 2) {
                Send-TextResponse -Stream $stream -StatusCode 400 -StatusText "Bad Request"
                continue
            }

            $method = $parts[0].ToUpperInvariant()
            $rawTarget = $parts[1]
            if ($method -ne "GET" -and $method -ne "HEAD") {
                Send-TextResponse -Stream $stream -StatusCode 405 -StatusText "Method Not Allowed"
                continue
            }

            $relativePath = Resolve-RequestPath -RawPath $rawTarget
            $fullPath = [System.IO.Path]::GetFullPath((Join-Path $rootPath $relativePath))
            if (-not $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                Send-TextResponse -Stream $stream -StatusCode 403 -StatusText "Forbidden"
                continue
            }

            if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
                Send-TextResponse -Stream $stream -StatusCode 404 -StatusText "Not Found"
                continue
            }

            $extension = [System.IO.Path]::GetExtension($fullPath).ToLowerInvariant()
            $contentType = $mimeTypes[$extension]
            if (-not $contentType) {
                $contentType = "application/octet-stream"
            }

            $bodyBytes = if ($method -eq "HEAD") { [byte[]]::new(0) } else { [System.IO.File]::ReadAllBytes($fullPath) }
            Send-BytesResponse -Stream $stream -StatusCode 200 -StatusText "OK" -BodyBytes $bodyBytes -ContentType $contentType
        }
        catch {
            if ($client -and $client.Connected) {
                try {
                    Send-TextResponse -Stream $client.GetStream() -StatusCode 500 -StatusText "Internal Server Error"
                }
                catch {
                }
            }
        }
        finally {
            if ($client) {
                $client.Close()
            }
        }
    }
}
finally {
    $listener.Stop()
}
