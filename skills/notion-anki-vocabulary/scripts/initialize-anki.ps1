param(
    [string]$ProfilePath = (Join-Path $env:LOCALAPPDATA 'NotionAnkiVocabulary\profile.json')
)

$ErrorActionPreference = 'Stop'
$resolvedProfilePath = [Environment]::ExpandEnvironmentVariables($ProfilePath)
if (-not (Test-Path -LiteralPath $resolvedProfilePath -PathType Leaf)) {
    throw "Local profile does not exist: $resolvedProfilePath"
}
$profile = Get-Content -LiteralPath $resolvedProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
$url = [string]$profile.anki.connect_url
$deck = [string]$profile.anki.deck
$model = [string]$profile.anki.model
$front = [string]$profile.anki.front_field
$back = [string]$profile.anki.back_field
if (-not $url -or -not $deck -or -not $model -or -not $front -or -not $back) {
    throw 'The Anki section of the profile is incomplete.'
}

function Invoke-Anki([string]$Action, [hashtable]$Params = @{}) {
    $request = @{ action = $Action; version = 6; params = $Params }
    if ($env:ANKI_CONNECT_API_KEY) { $request.key = $env:ANKI_CONNECT_API_KEY }
    $payload = $request | ConvertTo-Json -Depth 30 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $response = Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 30
    if ($null -ne $response.error) { throw "AnkiConnect $Action failed: $($response.error)" }
    return $response.result
}

$deckCreated = $false
if (-not (@(Invoke-Anki 'deckNames') -contains $deck)) {
    [void](Invoke-Anki 'createDeck' @{ deck = $deck })
    $deckCreated = $true
}

$modelCreated = $false
if (@(Invoke-Anki 'modelNames') -contains $model) {
    $fields = @(Invoke-Anki 'modelFieldNames' @{ modelName = $model })
    if (-not ($fields -contains $front) -or -not ($fields -contains $back)) {
        throw "Model '$model' exists but does not contain configured fields '$front' and '$back'. Choose another model name or configure compatible fields."
    }
}
else {
    $frontTemplate = '{{' + $front + '}}'
    $backTemplate = '{{FrontSide}}<hr id="answer">{{' + $back + '}}'
    [void](Invoke-Anki 'createModel' @{
        modelName = $model
        inOrderFields = @($front, $back)
        css = '.card { font-family: Arial; font-size: 22px; text-align: left; color: #1f2937; background: #ffffff; line-height: 1.5; } img { max-width: 100%; height: auto; }'
        isCloze = $false
        cardTemplates = @(@{ Name = 'Recall'; Front = $frontTemplate; Back = $backTemplate })
    })
    $modelCreated = $true
}

[PSCustomObject]@{
    ready = $true
    deck = $deck
    deck_created = $deckCreated
    model = $model
    model_created = $modelCreated
    fields = @($front, $back)
} | ConvertTo-Json -Depth 5
