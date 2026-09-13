[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$InstallAnki,
    [switch]$PrepareAnkiConnect,
    [string]$WingetExecutable,
    [string]$ProfilePath = (Join-Path $env:LOCALAPPDATA 'NotionAnkiVocabulary\profile.json')
)

$ErrorActionPreference = 'Stop'
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'The automatic prerequisite installer currently supports Windows only. Download Anki for your platform from https://apps.ankiweb.net/ and install AnkiConnect code 2055492159.'
}

function Find-AnkiExecutable {
    $command = Get-Command anki.exe -ErrorAction SilentlyContinue
    $candidates = @(
        $(if ($command) { $command.Source }),
        [Environment]::ExpandEnvironmentVariables('%LOCALAPPDATA%\Programs\Anki\anki.exe'),
        [Environment]::ExpandEnvironmentVariables('%PROGRAMFILES%\Anki\anki.exe')
    ) | Where-Object { $_ } | Select-Object -Unique
    return $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}

$ankiExecutable = Find-AnkiExecutable
$installedNow = $false
if (-not $ankiExecutable -and $InstallAnki) {
    $winget = if ($WingetExecutable) { Get-Command $WingetExecutable -ErrorAction SilentlyContinue } else { Get-Command winget -ErrorAction SilentlyContinue }
    if (-not $winget) {
        throw 'winget is unavailable. Install Anki from https://apps.ankiweb.net/ and rerun this script.'
    }
    if ($PSCmdlet.ShouldProcess('Anki.Anki from the Windows Package Manager', 'Install')) {
        & $winget.Source install --id Anki.Anki --exact --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "winget failed to install Anki (exit code $LASTEXITCODE)." }
        $installedNow = $true
        $ankiExecutable = Find-AnkiExecutable
        if (-not $ankiExecutable) { throw 'winget reported success, but anki.exe was not found in common locations.' }
    }
}

if ($ankiExecutable -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'configure.ps1'))) {
    if ($PSCmdlet.ShouldProcess($ProfilePath, 'Save detected Anki executable')) {
        & (Join-Path $PSScriptRoot 'configure.ps1') -ProfilePath $ProfilePath -AnkiExecutable $ankiExecutable | Out-Null
    }
}

$connectReady = $false
try {
    $request = @{ action = 'version'; version = 6 }
    if ($env:ANKI_CONNECT_API_KEY) { $request.key = $env:ANKI_CONNECT_API_KEY }
    $payload = $request | ConvertTo-Json -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $response = Invoke-RestMethod -Uri 'http://127.0.0.1:8765' -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 3
    $connectReady = $null -eq $response.error -and [int]$response.result -ge 6
}
catch { $connectReady = $false }

$requiresUserAction = $false
if ($ankiExecutable -and -not $connectReady -and $PrepareAnkiConnect) {
    $requiresUserAction = $true
    if ($PSCmdlet.ShouldProcess('Windows clipboard and Anki Desktop', 'Copy add-on code and open Anki for interactive add-on installation')) {
        Set-Clipboard -Value '2055492159'
        Start-Process -FilePath $ankiExecutable | Out-Null
    }
}

[PSCustomObject]@{
    windows = $true
    anki_found = [bool]$ankiExecutable
    anki_executable = [string]$ankiExecutable
    anki_installed_now = $installedNow
    ankiconnect_ready = $connectReady
    ankiconnect_addon_code = '2055492159'
    requires_user_action = $requiresUserAction
    user_action = if ($requiresUserAction) { 'In Anki choose Tools > Add-ons > Get Add-ons, paste 2055492159, install it, and restart Anki.' } else { '' }
} | ConvertTo-Json -Depth 5
