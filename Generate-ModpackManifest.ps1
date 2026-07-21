param(
    [string]$ModpackVersion = "1.0.0",
    [string]$Owner = "roamsito2018-spec",
    [string]$Repository = "MODPACK-LOSTHAVEN",
    [string]$Branch = "main"
)

$ErrorActionPreference = "Stop"

$root = (Get-Location).Path
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
    "manifest.json"
)

function Convert-ToUrlPath {
    param([string]$RelativePath)

    $segments = $RelativePath -split "[\\/]"
    $encodedSegments = foreach ($segment in $segments) {
        [System.Uri]::EscapeDataString($segment)
    }

    return ($encodedSegments -join "/")
}

Write-Host ""
Write-Host "Generando $outputName para Lost Haven..."
Write-Host "Carpeta: $root"
Write-Host ""

$files = Get-ChildItem -Path $root -File -Recurse |
    Where-Object {
        $relativePath = [System.IO.Path]::GetRelativePath($root, $_.FullName)
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

$manifestFiles = foreach ($file in $files) {
    $relativePath = [System.IO.Path]::GetRelativePath(
        $root,
        $file.FullName
    ).Replace("\", "/")

    $urlPath = Convert-ToUrlPath -RelativePath $relativePath
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

    [ordered]@{
        path = $relativePath
        url = "https://raw.githubusercontent.com/$Owner/$Repository/$Branch/$urlPath"
        size = $file.Length
        sha256 = $hash
    }
}

$manifest = [ordered]@{
    manifestVersion = 1
    modpackVersion = $ModpackVersion
    generatedAtUtc = [DateTimeOffset]::UtcNow.ToString("O")
    files = @($manifestFiles)
}

$json = $manifest |
    ConvertTo-Json -Depth 8

[System.IO.File]::WriteAllText(
    $outputPath,
    $json,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host ""
Write-Host "Manifest generado correctamente."
Write-Host "Archivos incluidos: $($manifestFiles.Count)"
Write-Host "Resultado: $outputPath"
Write-Host ""
Write-Host "Ahora subi los cambios con GitHub Desktop."
Write-Host ""
Read-Host "Presiona Enter para cerrar"
