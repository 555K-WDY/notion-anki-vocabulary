param(
    [Parameter(Mandatory = $true)][string]$Cue,
    [string]$Emoji = '💡',
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [string]$Background = '#EEF2FF',
    [string]$Accent = '#4F46E5'
)

$ErrorActionPreference = 'Stop'
function Escape-Xml([string]$Text) { return [Security.SecurityElement]::Escape($Text) }

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
if ([IO.Path]::GetExtension($resolvedOutput).ToLowerInvariant() -ne '.svg') {
    throw 'OutputPath must end in .svg.'
}
$directory = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$safeCue = Escape-Xml $Cue
$safeEmoji = Escape-Xml $Emoji
$safeBackground = Escape-Xml $Background
$safeAccent = Escape-Xml $Accent
$svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="900" height="600" viewBox="0 0 900 600">
  <rect width="900" height="600" rx="42" fill="$safeBackground"/>
  <circle cx="450" cy="210" r="118" fill="$safeAccent" opacity="0.15"/>
  <text x="450" y="255" text-anchor="middle" font-size="128">$safeEmoji</text>
  <foreignObject x="100" y="360" width="700" height="160">
    <div xmlns="http://www.w3.org/1999/xhtml" style="font-family:Arial,'Microsoft YaHei',sans-serif;font-size:42px;line-height:1.35;text-align:center;color:#111827;">$safeCue</div>
  </foreignObject>
</svg>
"@
$svg | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8

[PSCustomObject]@{
    created = Test-Path -LiteralPath $resolvedOutput -PathType Leaf
    path = $resolvedOutput
    bytes = (Get-Item -LiteralPath $resolvedOutput).Length
} | ConvertTo-Json
