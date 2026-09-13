param(
    [string]$DestinationPath = (Join-Path (Get-Location) 'notion-anki-vocabulary-skill.zip')
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$destination = [IO.Path]::GetFullPath($DestinationPath)
$destinationDirectory = Split-Path -Parent $destination

if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
    New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
}
if (Test-Path -LiteralPath $destination) {
    throw "Destination already exists: $destination"
}

Compress-Archive -Path (Join-Path $skillRoot '*') -DestinationPath $destination -CompressionLevel Optimal

[PSCustomObject]@{
    SkillRoot = $skillRoot
    Archive = $destination
    Bytes = (Get-Item -LiteralPath $destination).Length
} | ConvertTo-Json
