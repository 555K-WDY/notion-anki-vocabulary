param(
    [string]$ProfilePath = (Join-Path $env:LOCALAPPDATA 'NotionAnkiVocabulary\profile.json'),
    [string]$AnkiExecutable,
    [string]$AnkiProfile,
    [string]$AnkiConnectUrl,
    [ValidateRange(5, 300)][int]$TimeoutSeconds = 60,
    [ValidateRange(1, 10)][int]$PollSeconds = 2
)

$ErrorActionPreference = 'Stop'

$resolvedProfilePath = [Environment]::ExpandEnvironmentVariables($ProfilePath)
if (Test-Path -LiteralPath $resolvedProfilePath -PathType Leaf) {
    $profile = Get-Content -LiteralPath $resolvedProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $PSBoundParameters.ContainsKey('AnkiExecutable')) { $AnkiExecutable = [string]$profile.anki.executable }
    if (-not $PSBoundParameters.ContainsKey('AnkiProfile')) { $AnkiProfile = [string]$profile.anki.profile }
    if (-not $PSBoundParameters.ContainsKey('AnkiConnectUrl')) { $AnkiConnectUrl = [string]$profile.anki.connect_url }
}
if (-not $AnkiConnectUrl) { $AnkiConnectUrl = 'http://127.0.0.1:8765' }
if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This release supports automatic local Anki startup on Windows only.'
}

function Test-AnkiConnect {
    try {
        $requestObject = @{ action = 'version'; version = 6 }
        if ($env:ANKI_CONNECT_API_KEY) { $requestObject.key = $env:ANKI_CONNECT_API_KEY }
        $request = $requestObject | ConvertTo-Json -Compress
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($request)
        $response = Invoke-RestMethod -Uri $AnkiConnectUrl -Method Post `
            -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 3
        return ($null -eq $response.error -and [int]$response.result -ge 6)
    }
    catch {
        return $false
    }
}

function Resolve-AnkiExecutable {
    param([string]$ExplicitPath)

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($ExplicitPath) { $candidates.Add([Environment]::ExpandEnvironmentVariables($ExplicitPath)) }
    $candidates.Add([Environment]::ExpandEnvironmentVariables('%LOCALAPPDATA%\Programs\Anki\anki.exe'))
    $candidates.Add([Environment]::ExpandEnvironmentVariables('%PROGRAMFILES%\Anki\anki.exe'))

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "Anki executable was not found. Pass -AnkiExecutable with the full path. Checked: $($candidates -join '; ')"
}

$launched = $false
$resolvedExecutable = $null

if (-not (Test-AnkiConnect)) {
    $resolvedExecutable = Resolve-AnkiExecutable -ExplicitPath $AnkiExecutable
    $ankiProcess = Get-Process -Name 'Anki' -ErrorAction SilentlyContinue
    if ($null -eq $ankiProcess) {
        $arguments = @()
        if ($AnkiProfile) { $arguments = @('-p', $AnkiProfile) }
        Start-Process -FilePath $resolvedExecutable -ArgumentList $arguments -WindowStyle Hidden | Out-Null
        $launched = $true
    }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds $PollSeconds
        if (Test-AnkiConnect) { break }
    } while ((Get-Date) -lt $deadline)
}

$ready = Test-AnkiConnect
if (-not $ready) {
    throw "Anki is running or was started, but AnkiConnect did not become ready at $AnkiConnectUrl within $TimeoutSeconds seconds."
}

[PSCustomObject]@{
    Ready = $ready
    Launched = $launched
    Executable = $resolvedExecutable
    AnkiConnect = $AnkiConnectUrl
} | ConvertTo-Json
