[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$DestinationRoot = (Join-Path $env:USERPROFILE '.codex\skills'),
    [switch]$Update
)

$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'skills\notion-anki-vocabulary'
$destinationRootPath = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($DestinationRoot))
$destination = Join-Path $destinationRootPath 'notion-anki-vocabulary'
if (-not (Test-Path -LiteralPath (Join-Path $source 'SKILL.md') -PathType Leaf)) {
    throw "Skill source is incomplete: $source"
}
if (Test-Path -LiteralPath $destination) {
    if (-not $Update) { throw "Skill already exists at $destination. Use -Update to replace it with a backup." }
    $backupRoot = Join-Path $env:LOCALAPPDATA 'NotionAnkiVocabulary\skill-backups'
    if (-not (Test-Path -LiteralPath $backupRoot -PathType Container)) {
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
    }
    $backup = Join-Path $backupRoot "notion-anki-vocabulary-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($PSCmdlet.ShouldProcess($destination, "Move existing skill to $backup")) {
        Move-Item -LiteralPath $destination -Destination $backup
    }
}
if (-not (Test-Path -LiteralPath $destinationRootPath -PathType Container)) {
    New-Item -ItemType Directory -Path $destinationRootPath -Force | Out-Null
}
if ($PSCmdlet.ShouldProcess($destination, 'Install skill')) {
    Copy-Item -LiteralPath $source -Destination $destination -Recurse
}

[PSCustomObject]@{
    installed = Test-Path -LiteralPath (Join-Path $destination 'SKILL.md') -PathType Leaf
    destination = $destination
    next_prompt = 'Use $notion-anki-vocabulary to initialize my vocabulary system.'
} | ConvertTo-Json
