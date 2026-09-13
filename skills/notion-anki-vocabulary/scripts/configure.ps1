param(
    [string]$ProfilePath = (Join-Path $env:LOCALAPPDATA 'NotionAnkiVocabulary\profile.json'),
    [string]$NotionPageUrl,
    [string]$NotionPageId,
    [string]$NotionDataSource,
    [string]$NotionDatabaseTitle,
    [string]$AnkiExecutable,
    [string]$AnkiProfile,
    [string]$AnkiConnectUrl,
    [string]$Deck,
    [string]$Model,
    [string]$FrontField,
    [string]$BackField,
    [Nullable[bool]]$ScheduleEnabled,
    [string]$ScheduleTime,
    [string]$ScheduleTimezone
)

$ErrorActionPreference = 'Stop'

function New-DefaultProfile {
    return [ordered]@{
        schema_version = 1
        notion = [ordered]@{
            page_url = ''
            page_id = ''
            data_source = ''
            database_title = '词汇整理库'
        }
        anki = [ordered]@{
            executable = ''
            profile = ''
            connect_url = 'http://127.0.0.1:8765'
            deck = 'Vocabulary::Active'
            model = 'Notion Anki Vocabulary'
            front_field = 'Front'
            back_field = 'Back'
        }
        schedule = [ordered]@{
            enabled = $false
            time = '07:00'
            timezone = 'local'
        }
    }
}

function Add-MissingProperties {
    param(
        [Parameter(Mandatory)]$Target,
        [Parameter(Mandatory)]$Defaults
    )
    foreach ($property in $Defaults.PSObject.Properties) {
        if (-not $Target.PSObject.Properties[$property.Name]) {
            $Target | Add-Member -NotePropertyName $property.Name -NotePropertyValue $property.Value
        }
    }
}

$resolvedProfilePath = [Environment]::ExpandEnvironmentVariables($ProfilePath)
if (Test-Path -LiteralPath $resolvedProfilePath -PathType Leaf) {
    $profile = Get-Content -LiteralPath $resolvedProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
}
else {
    $profile = [PSCustomObject](New-DefaultProfile)
    $profile.notion = [PSCustomObject]$profile.notion
    $profile.anki = [PSCustomObject]$profile.anki
    $profile.schedule = [PSCustomObject]$profile.schedule
}

$defaults = [PSCustomObject](New-DefaultProfile)
$defaults.notion = [PSCustomObject]$defaults.notion
$defaults.anki = [PSCustomObject]$defaults.anki
$defaults.schedule = [PSCustomObject]$defaults.schedule
Add-MissingProperties -Target $profile -Defaults $defaults
foreach ($sectionName in @('notion', 'anki', 'schedule')) {
    if ($null -eq $profile.$sectionName) {
        $profile.$sectionName = $defaults.$sectionName
    }
    else {
        Add-MissingProperties -Target $profile.$sectionName -Defaults $defaults.$sectionName
    }
}
$profile.schema_version = 1

$updates = @{
    NotionPageUrl = @($profile.notion, 'page_url')
    NotionPageId = @($profile.notion, 'page_id')
    NotionDataSource = @($profile.notion, 'data_source')
    NotionDatabaseTitle = @($profile.notion, 'database_title')
    AnkiExecutable = @($profile.anki, 'executable')
    AnkiProfile = @($profile.anki, 'profile')
    AnkiConnectUrl = @($profile.anki, 'connect_url')
    Deck = @($profile.anki, 'deck')
    Model = @($profile.anki, 'model')
    FrontField = @($profile.anki, 'front_field')
    BackField = @($profile.anki, 'back_field')
    ScheduleTime = @($profile.schedule, 'time')
    ScheduleTimezone = @($profile.schedule, 'timezone')
}

foreach ($parameterName in $updates.Keys) {
    if ($PSBoundParameters.ContainsKey($parameterName)) {
        $target = $updates[$parameterName][0]
        $property = $updates[$parameterName][1]
        $target.$property = [string]$PSBoundParameters[$parameterName]
    }
}
if ($PSBoundParameters.ContainsKey('ScheduleEnabled')) {
    $profile.schedule.enabled = [bool]$ScheduleEnabled
}

$directory = Split-Path -Parent ([IO.Path]::GetFullPath($resolvedProfilePath))
if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}
$profile | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resolvedProfilePath -Encoding UTF8

[PSCustomObject]@{
    profile_path = [IO.Path]::GetFullPath($resolvedProfilePath)
    schema_version = $profile.schema_version
    notion_configured = [bool]($profile.notion.page_id -and $profile.notion.data_source)
    anki_executable_configured = [bool]$profile.anki.executable
    deck = $profile.anki.deck
    model = $profile.anki.model
} | ConvertTo-Json
