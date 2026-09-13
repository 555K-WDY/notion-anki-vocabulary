param(
    [string]$ProfilePath = (Join-Path $env:LOCALAPPDATA 'NotionAnkiVocabulary\profile.json'),
    [switch]$SkipAudioCheck,
    [switch]$RequireReady
)

$ErrorActionPreference = 'Stop'
$issues = New-Object System.Collections.Generic.List[string]
$actions = New-Object System.Collections.Generic.List[string]
$resolvedProfilePath = [Environment]::ExpandEnvironmentVariables($ProfilePath)
$isWindowsHost = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT

if (-not $isWindowsHost) {
    $issues.Add('This release supports local Anki automation on Windows only.')
    $actions.Add('Run the skill in a local Windows Codex session.')
}

$profile = $null
if (Test-Path -LiteralPath $resolvedProfilePath -PathType Leaf) {
    try { $profile = Get-Content -LiteralPath $resolvedProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch {
        $issues.Add("Profile is not valid JSON: $($_.Exception.Message)")
        $actions.Add('Run configure.ps1 to recreate the local profile.')
    }
}
else {
    $issues.Add("Local profile does not exist: $resolvedProfilePath")
    $actions.Add('Run configure.ps1, then complete Notion bootstrap.')
}

$notionConfigured = $false
$ankiExecutableFound = $false
$ankiConnectReady = $false
$ankiConnectVersion = $null
$audioVoiceAvailable = $SkipAudioCheck

if ($null -ne $profile) {
    $notionConfigured = [bool]($profile.notion.page_id -and $profile.notion.data_source)
    if (-not $notionConfigured) {
        $issues.Add('Notion page ID or data-source URL is missing from the local profile.')
        $actions.Add('Run bootstrap mode and save the verified Notion identifiers with configure.ps1.')
    }

    $configuredExecutable = [Environment]::ExpandEnvironmentVariables([string]$profile.anki.executable)
    $candidates = @(
        $configuredExecutable,
        [Environment]::ExpandEnvironmentVariables('%LOCALAPPDATA%\Programs\Anki\anki.exe'),
        [Environment]::ExpandEnvironmentVariables('%PROGRAMFILES%\Anki\anki.exe')
    ) | Where-Object { $_ } | Select-Object -Unique
    $ankiExecutableFound = [bool]($candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1)
    if (-not $ankiExecutableFound) {
        $issues.Add('Anki executable was not found in the configured or common locations.')
        $actions.Add('Run configure.ps1 -AnkiExecutable with the full path to anki.exe.')
    }

    $url = if ($profile.anki.connect_url) { [string]$profile.anki.connect_url } else { 'http://127.0.0.1:8765' }
    try {
        $request = @{ action = 'version'; version = 6 }
        if ($env:ANKI_CONNECT_API_KEY) { $request.key = $env:ANKI_CONNECT_API_KEY }
        $payload = $request | ConvertTo-Json -Compress
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        $response = Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 3
        if ($null -eq $response.error) {
            $ankiConnectVersion = [int]$response.result
            $ankiConnectReady = $ankiConnectVersion -ge 6
        }
    }
    catch { $ankiConnectReady = $false }
    if (-not $ankiConnectReady) {
        $issues.Add("AnkiConnect is not reachable at $url.")
        $actions.Add('Install/enable AnkiConnect, restart Anki, or run ensure-anki.ps1.')
    }
}

if ($isWindowsHost -and -not $SkipAudioCheck) {
    $voice = $null
    try {
        $voice = New-Object -ComObject SAPI.SpVoice
        $audioVoiceAvailable = [bool](@($voice.GetVoices()) | Where-Object { $_.GetDescription() -match 'English|Zira|David|Mark' } | Select-Object -First 1)
    }
    catch { $audioVoiceAvailable = $false }
    finally { if ($null -ne $voice) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($voice) } }
    if (-not $audioVoiceAvailable) {
        $issues.Add('No matching English Windows speech voice was found.')
        $actions.Add('Install an English Windows speech voice or configure a matching VoicePattern.')
    }
}

$ready = $isWindowsHost -and $null -ne $profile -and $notionConfigured -and $ankiExecutableFound -and $ankiConnectReady -and $audioVoiceAvailable
$report = [PSCustomObject]@{
    ready = $ready
    windows = $isWindowsHost
    profile_path = [IO.Path]::GetFullPath($resolvedProfilePath)
    profile_exists = Test-Path -LiteralPath $resolvedProfilePath -PathType Leaf
    notion_configured = $notionConfigured
    anki_executable_found = $ankiExecutableFound
    anki_connect_ready = $ankiConnectReady
    anki_connect_version = $ankiConnectVersion
    audio_voice_available = $audioVoiceAvailable
    issues = [string[]]$issues
    next_actions = [string[]]$actions
}

$report | ConvertTo-Json -Depth 8
if ($RequireReady -and -not $ready) { exit 1 }
