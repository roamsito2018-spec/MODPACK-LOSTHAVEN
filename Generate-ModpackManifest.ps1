param(
    [string]$ModpackVersion = "1.0.0",
    [string]$Owner = "roamsito2018-spec",
    [string]$Repository = "MODPACK-LOSTHAVEN",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

$root = (Get-Location).Path.TrimEnd("\")
$outputName = "modpack-manifest.json"
$outputPath = Join-Path $root $outputName

$excludedDirectories = @(
    ".git",
    ".github",
    ".idea",
    ".vs",
    "bin",
    "obj",
    "saves",
    "logs",
    "crash-reports",
    "screenshots"
)

$excludedFiles = @(
    $outputName,
    "Generate-ModpackManifest.ps1",
    "Generate-ModpackManifest-FIX.ps1",
    "Generate-ModpackManifest-FIX2.ps1",
    "manifest.json"
)

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$FullPath
    )

    $normalizedBase = [System.IO.Path]::GetFullPath($BasePath).TrimEnd("\") + "\"
    $normalizedFull = [System.IO.Path]::GetFullPath($FullPath)

    if (-not $normalizedFull.StartsWith(
        $normalizedBase,
        [System.StringComparison]::OrdinalIgnoreCase))
    {
        throw "El archivo '$normalizedFull' no está dentro de '$normalizedBase'."
    }

    return $normalizedFull.Substring($normalizedBase.Length)
}

function Convert-ToUrlPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $segments = $RelativePath -split "[\\/]"
    $encodedSegments = foreach ($segment in $segments) {
        [System.Uri]::EscapeDataString($segment)
    }

    return ($encodedSegments -join "/")
}

function Get-Sha256 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $stream = $null
    $sha256 = $null

    try {
        $stream = [System.IO.File]::Open(
            $FilePath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::Read
        )

        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($stream)

        return (
            [System.BitConverter]::ToString($hashBytes)
        ).Replace("-", "").ToLower()
    }
    finally {
        if ($sha256 -ne $null) {
            $sha256.Dispose()
        }

        if ($stream -ne $null) {
            $stream.Dispose()
        }
    }
}

Write-Host ""
Write-Host "Generando $outputName para Lost Haven..."
Write-Host "Carpeta: $root"
Write-Host ""

$files = Get-ChildItem -Path $root -File -Recurse |
    Where-Object {
        $relativePath = Get-RelativePath -BasePath $root -FullPath $_.FullName
        $parts = $relativePath -split "[\\/]"

        $containsExcludedDirectory = $false

        foreach ($directory in $excludedDirectories) {
            if ($parts -contains $directory) {
                $containsExcludedDirectory = $true
                break
            }
        }

        -not $containsExcludedDirectory -and
        $excludedFiles -notcontains $_.Name -and
        -not $_.Name.EndsWith(".losthaven.download")
    } |
    Sort-Object FullName

$manifestFiles = @()
$index = 0

foreach ($file in $files) {
    $index++

    $relativePath = (
        Get-RelativePath -BasePath $root -FullPath $file.FullName
    ).Replace("\", "/")

    try {
        Write-Host "[$index/$($files.Count)] Procesando: $relativePath"

        $urlPath = Convert-ToUrlPath -RelativePath $relativePath
        $hash = Get-Sha256 -FilePath $file.FullName

        if ([string]::IsNullOrWhiteSpace($hash)) {
            throw "No se pudo calcular el SHA-256."
        }

        $manifestFiles += [ordered]@{
            path = $relativePath
            url = "https://raw.githubusercontent.com/$Owner/$Repository/$Branch/$urlPath"
            size = [int64]$file.Length
            sha256 = $hash
        }
    }
    catch {
        Write-Host ""
        Write-Host "ERROR procesando: $relativePath" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Write-Host ""
        throw
    }
}

$manifest = [ordered]@{
    manifestVersion = 1
    modpackVersion = $ModpackVersion
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    files = $manifestFiles
}

$json = $manifest | ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    (New-Object System.Text.UTF8Encoding($false))
)

Write-Host ""
Write-Host "Manifest generado correctamente." -ForegroundColor Green
Write-Host "Archivos incluidos: $($manifestFiles.Count)"
Write-Host "Resultado: $outputPath"
Write-Host ""
Write-Host "Ahora subí modpack-manifest.json con GitHub Desktop."
Write-Host ""
Read-Host "Presioná Enter para cerrar"
