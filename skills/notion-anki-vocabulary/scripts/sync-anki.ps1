param(
    [Parameter(Mandatory = $true)][string]$DataPath,
    [string]$ProfilePath = (Join-Path $env:LOCALAPPDATA 'NotionAnkiVocabulary\profile.json'),
    [string]$MediaRoot,
    [string]$ResultPath,
    [string]$Deck,
    [string]$Model,
    [string]$FrontField,
    [string]$BackField,
    [string]$AnkiConnectUrl,
    [string]$RunId = (Get-Date -Format 'yyyy-MM-dd-HHmmss'),
    [string]$VoicePattern = 'English|Zira|David|Mark',
    [ValidateSet('Sapi', 'SilentTest')][string]$AudioMode = 'Sapi',
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'

$resolvedProfilePath = [Environment]::ExpandEnvironmentVariables($ProfilePath)
if (Test-Path -LiteralPath $resolvedProfilePath -PathType Leaf) {
    $profile = Get-Content -LiteralPath $resolvedProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (-not $PSBoundParameters.ContainsKey('Deck')) { $Deck = [string]$profile.anki.deck }
    if (-not $PSBoundParameters.ContainsKey('Model')) { $Model = [string]$profile.anki.model }
    if (-not $PSBoundParameters.ContainsKey('FrontField')) { $FrontField = [string]$profile.anki.front_field }
    if (-not $PSBoundParameters.ContainsKey('BackField')) { $BackField = [string]$profile.anki.back_field }
    if (-not $PSBoundParameters.ContainsKey('AnkiConnectUrl')) { $AnkiConnectUrl = [string]$profile.anki.connect_url }
}
if (-not $Deck) { $Deck = 'Vocabulary::Active' }
if (-not $Model) { $Model = 'Notion Anki Vocabulary' }
if (-not $FrontField) { $FrontField = 'Front' }
if (-not $BackField) { $BackField = 'Back' }
if (-not $AnkiConnectUrl) { $AnkiConnectUrl = 'http://127.0.0.1:8765' }

function Invoke-Anki([string]$Action, [hashtable]$Params = @{}) {
    $request = @{ action = $Action; version = 6; params = $Params }
    if ($env:ANKI_CONNECT_API_KEY) { $request.key = $env:ANKI_CONNECT_API_KEY }
    $payload = $request | ConvertTo-Json -Depth 40 -Compress
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $response = Invoke-RestMethod -Uri $AnkiConnectUrl -Method Post `
        -ContentType 'application/json; charset=utf-8' -Body $bytes -TimeoutSec 30
    if ($null -ne $response.error) { throw "AnkiConnect $Action failed: $($response.error)" }
    return $response.result
}

function Encode-Html([string]$Text) { return [Net.WebUtility]::HtmlEncode($Text) }

function Normalize-Target([string]$Text) {
    $plain = [Net.WebUtility]::HtmlDecode(($Text -replace '<[^>]+>', ''))
    return (($plain -replace '\s+', ' ').Trim().ToLowerInvariant())
}

function Get-ShortHash([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').Substring(0, 16).ToLowerInvariant()
    }
    finally { $sha.Dispose() }
}

function Resolve-Examples($Item) {
    $values = New-Object System.Collections.Generic.List[string]
    if ($null -ne $Item.examples) {
        foreach ($example in @($Item.examples)) {
            $text = ([string]$example).Trim()
            if ($text) { $values.Add($text) }
        }
    }
    if ($values.Count -eq 0 -and $null -ne $Item.example) {
        $text = ([string]$Item.example).Trim()
        if ($text) { $values.Add($text) }
    }
    return @($values)
}

function Speak-Wav([string]$Text, [string]$Path) {
    if ($AudioMode -eq 'SilentTest') {
        if ($env:NOTION_ANKI_TEST_MODE -ne '1') { throw 'SilentTest audio is restricted to the test harness.' }
        $sampleRate = 8000
        $dataLength = 800
        $bytes = New-Object byte[] (44 + $dataLength)
        [Text.Encoding]::ASCII.GetBytes('RIFF').CopyTo($bytes, 0)
        [BitConverter]::GetBytes([int](36 + $dataLength)).CopyTo($bytes, 4)
        [Text.Encoding]::ASCII.GetBytes('WAVEfmt ').CopyTo($bytes, 8)
        [BitConverter]::GetBytes([int]16).CopyTo($bytes, 16)
        [BitConverter]::GetBytes([int16]1).CopyTo($bytes, 20)
        [BitConverter]::GetBytes([int16]1).CopyTo($bytes, 22)
        [BitConverter]::GetBytes([int]$sampleRate).CopyTo($bytes, 24)
        [BitConverter]::GetBytes([int]$sampleRate).CopyTo($bytes, 28)
        [BitConverter]::GetBytes([int16]1).CopyTo($bytes, 32)
        [BitConverter]::GetBytes([int16]8).CopyTo($bytes, 34)
        [Text.Encoding]::ASCII.GetBytes('data').CopyTo($bytes, 36)
        [BitConverter]::GetBytes([int]$dataLength).CopyTo($bytes, 40)
        for ($offset = 44; $offset -lt $bytes.Length; $offset++) { $bytes[$offset] = 128 }
        [IO.File]::WriteAllBytes($Path, $bytes)
        return
    }
    $voice = New-Object -ComObject SAPI.SpVoice
    $stream = $null
    try {
        foreach ($candidate in @($voice.GetVoices())) {
            if ($candidate.GetDescription() -match $VoicePattern) { $voice.Voice = $candidate; break }
        }
        $voice.Rate = -1
        $stream = New-Object -ComObject SAPI.SpFileStream
        $stream.Format.Type = 22
        $stream.Open($Path, 3, $false)
        $voice.AudioOutputStream = $stream
        [void]$voice.Speak($Text)
        $stream.Close()
    }
    finally {
        if ($null -ne $stream) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($stream) }
        if ($null -ne $voice) { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($voice) }
    }
}

function Store-Media([string]$Path, [string]$Name) {
    $data = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    $stored = Invoke-Anki 'storeMediaFile' @{ filename = $Name; data = $data }
    if ($stored -ne $Name) { throw "Media mismatch: $Name -> $stored" }
}

function Get-TargetMap {
    $escapedDeck = $Deck.Replace('"', '\"')
    $ids = @(Invoke-Anki 'findNotes' @{ query = "deck:`"$escapedDeck`"" })
    $map = @{}
    if ($ids.Count -gt 0) {
        foreach ($note in @(Invoke-Anki 'notesInfo' @{ notes = $ids })) {
            $back = [string]$note.fields.$BackField.value
            if ($back -match '(?is)<b>(.*?)</b>') {
                $key = Normalize-Target $Matches[1]
                if (-not $map.ContainsKey($key)) { $map[$key] = New-Object System.Collections.Generic.List[long] }
                $map[$key].Add([long]$note.noteId)
            }
        }
    }
    return $map
}

$resolvedDataPath = (Resolve-Path -LiteralPath $DataPath).Path
if (-not $MediaRoot) { $MediaRoot = Split-Path -Parent $resolvedDataPath }
$resolvedMediaRoot = (Resolve-Path -LiteralPath $MediaRoot).Path
if (-not $ResultPath) { $ResultPath = Join-Path $resolvedMediaRoot 'notion-anki-sync-result.json' }

$data = @(Get-Content -Raw -Encoding UTF8 -LiteralPath $resolvedDataPath | ConvertFrom-Json)
if ($data.Count -eq 0) { throw 'The batch is empty.' }

$prepared = New-Object System.Collections.Generic.List[object]
$targetKeys = @{}
$imageHashes = @{}
foreach ($item in $data) {
    $target = ([string]$item.target).Trim()
    $meaning = ([string]$item.meaning).Trim()
    $scenario = ([string]$item.scenario).Trim()
    if (-not $target -or -not $meaning -or -not $scenario) {
        throw "Each row requires non-empty target, meaning, and scenario. Invalid index: $($item.index)"
    }
    $targetKey = Normalize-Target $target
    if ($targetKeys.ContainsKey($targetKey)) { throw "Duplicate target in batch: $target" }
    $targetKeys[$targetKey] = $true

    $examples = @(Resolve-Examples $item)
    if ($examples.Count -eq 0) { throw "At least one example is required for: $target" }

    $imageInput = ([string]$item.image).Trim()
    if (-not $imageInput) { throw "Image is required for: $target" }
    $imagePath = if ([IO.Path]::IsPathRooted($imageInput)) { $imageInput } else { Join-Path $resolvedMediaRoot $imageInput }
    if (-not (Test-Path -LiteralPath $imagePath -PathType Leaf)) { throw "Missing image for ${target}: $imagePath" }
    $imagePath = (Resolve-Path -LiteralPath $imagePath).Path
    $imageHash = (Get-FileHash -LiteralPath $imagePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($imageHashes.ContainsKey($imageHash)) { throw "Two batch items reuse identical image content: $target and $($imageHashes[$imageHash])" }
    $imageHashes[$imageHash] = $target

    $extension = [IO.Path]::GetExtension($imagePath).ToLowerInvariant()
    if ($extension -notin @('.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg')) {
        throw "Unsupported image type for ${target}: $extension"
    }
    $stableHash = Get-ShortHash $targetKey
    $prepared.Add([PSCustomObject]@{
        source = $item
        target = $target
        target_key = $targetKey
        meaning = $meaning
        scenario = $scenario
        examples = $examples
        image_path = $imagePath
        image_name = "notion-anki-$stableHash-image$extension"
        stable_hash = $stableHash
    })
}

$validation = [PSCustomObject]@{
    valid = $true
    item_count = $prepared.Count
    unique_target_count = $targetKeys.Count
    unique_image_content_count = $imageHashes.Count
    data_path = $resolvedDataPath
    media_root = $resolvedMediaRoot
}

if ($ValidateOnly) {
    $validation | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
    $validation | ConvertTo-Json -Depth 8
    exit 0
}

$deckNames = @(Invoke-Anki 'deckNames')
if (-not ($deckNames -contains $Deck)) { [void](Invoke-Anki 'createDeck' @{ deck = $Deck }) }
$modelNames = @(Invoke-Anki 'modelNames')
if (-not ($modelNames -contains $Model)) {
    $frontTemplate = '{{' + $FrontField + '}}'
    $backTemplate = '{{FrontSide}}<hr id="answer">{{' + $BackField + '}}'
    [void](Invoke-Anki 'createModel' @{
        modelName = $Model
        inOrderFields = @($FrontField, $BackField)
        css = '.card { font-family: Arial; font-size: 22px; text-align: left; color: #1f2937; background: #ffffff; line-height: 1.5; } img { max-width: 100%; height: auto; }'
        isCloze = $false
        cardTemplates = @(@{ Name = 'Recall'; Front = $frontTemplate; Back = $backTemplate })
    })
}
$fieldNames = @(Invoke-Anki 'modelFieldNames' @{ modelName = $Model })
if (-not ($fieldNames -contains $FrontField) -or -not ($fieldNames -contains $BackField)) {
    throw "Model '$Model' must contain fields '$FrontField' and '$BackField'."
}

$existing = Get-TargetMap
$results = New-Object System.Collections.Generic.List[object]
$duplicateExisting = New-Object System.Collections.Generic.List[object]
$added = 0
$updated = 0

foreach ($item in $prepared) {
    Store-Media $item.image_path $item.image_name

    $targetAudioTags = New-Object System.Collections.Generic.List[string]
    $targetAudioNames = New-Object System.Collections.Generic.List[string]
    $parts = @($item.target -split '\s+/\s+' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    for ($partIndex = 0; $partIndex -lt $parts.Count; $partIndex++) {
        $part = $parts[$partIndex]
        $partHash = Get-ShortHash ((Normalize-Target $part) + '|target-audio')
        $name = "notion-anki-$($item.stable_hash)-target-$('{0:D2}' -f ($partIndex + 1))-$partHash.wav"
        $path = Join-Path $resolvedMediaRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Speak-Wav $part $path }
        Store-Media $path $name
        $targetAudioNames.Add($name)
        $targetAudioTags.Add("[sound:$name]")
    }

    $exampleBlocks = New-Object System.Collections.Generic.List[string]
    $exampleAudioNames = New-Object System.Collections.Generic.List[string]
    for ($exampleIndex = 0; $exampleIndex -lt $item.examples.Count; $exampleIndex++) {
        $example = [string]$item.examples[$exampleIndex]
        $exampleHash = Get-ShortHash ($item.target_key + '|example|' + $example)
        $name = "notion-anki-$($item.stable_hash)-example-$('{0:D2}' -f ($exampleIndex + 1))-$exampleHash.wav"
        $path = Join-Path $resolvedMediaRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Speak-Wav $example $path }
        Store-Media $path $name
        $exampleAudioNames.Add($name)
        $exampleBlocks.Add((Encode-Html $example) + "<br>[sound:$name]")
    }

    $front = '<b>常用中文：</b>' + (Encode-Html $item.meaning) + '<br><br><b>情景：</b>' + (Encode-Html $item.scenario)
    $back = '<b>' + (Encode-Html $item.target) + '</b><br><br><b>重点读音：</b>' + `
        ($targetAudioTags -join ' ') + '<br><br><b>例句：</b><br>' + `
        ($exampleBlocks -join '<br><br>') + '<br><br><img src="' + $item.image_name + '">'

    $fields = @{}; $fields[$FrontField] = $front; $fields[$BackField] = $back
    $status = $null
    $noteId = $null
    if ($existing.ContainsKey($item.target_key)) {
        $ids = @($existing[$item.target_key])
        $noteId = [long]$ids[0]
        if ($ids.Count -gt 1) {
            $duplicateExisting.Add([PSCustomObject]@{ target = $item.target; note_ids = [long[]]$ids })
        }
        [void](Invoke-Anki 'updateNoteFields' @{ note = @{ id = $noteId; fields = $fields } })
        [void](Invoke-Anki 'addTags' @{ notes = @($noteId); tags = "IELTS 主动词汇 notion-sync multimodal audio $RunId" })
        $updated++
        $status = 'updated'
    }
    else {
        $note = @{
            deckName = $Deck
            modelName = $Model
            fields = $fields
            options = @{ allowDuplicate = $false }
            tags = @('IELTS', '主动词汇', 'notion-sync', 'multimodal', 'audio', $RunId)
        }
        $noteId = Invoke-Anki 'addNote' @{ note = $note }
        if ($null -eq $noteId) { throw "addNote returned null for $($item.target)" }
        $existing[$item.target_key] = New-Object System.Collections.Generic.List[long]
        $existing[$item.target_key].Add([long]$noteId)
        $added++
        $status = 'added'
    }

    $results.Add([PSCustomObject]@{
        index = $item.source.index
        page_id = [string]$item.source.page_id
        target = $item.target
        note_id = [long]$noteId
        status = $status
        image = $item.image_name
        target_audio = [string[]]$targetAudioNames
        example_audio = [string[]]$exampleAudioNames
    })
}

$processedIds = @($results | ForEach-Object { [long]$_.note_id })
$processedNotes = if ($processedIds.Count -gt 0) { @(Invoke-Anki 'notesInfo' @{ notes = $processedIds }) } else { @() }
$byId = @{}; foreach ($note in $processedNotes) { $byId[[string]$note.noteId] = $note }
$fronts = New-Object System.Collections.Generic.List[string]
$images = New-Object System.Collections.Generic.List[string]
$missingMedia = New-Object System.Collections.Generic.List[string]
$badFronts = New-Object System.Collections.Generic.List[string]
$badAudio = New-Object System.Collections.Generic.List[string]

foreach ($result in $results) {
    $key = [string]$result.note_id
    if (-not $byId.ContainsKey($key)) { $missingMedia.Add("NOTE:$($result.target)"); continue }
    $note = $byId[$key]
    $front = [string]$note.fields.$FrontField.value
    $back = [string]$note.fields.$BackField.value
    $fronts.Add($front)
    if ($front -notmatch '常用中文' -or $front -notmatch '情景') { $badFronts.Add([string]$result.target) }

    $audioNames = @([regex]::Matches($back, '\[sound:([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value })
    $expectedAudioCount = @($result.target_audio).Count + @($result.example_audio).Count
    if ($audioNames.Count -ne $expectedAudioCount) { $badAudio.Add([string]$result.target) }
    foreach ($name in $audioNames) {
        if (-not (@(Invoke-Anki 'getMediaFilesNames' @{ pattern = $name }) -contains $name)) { $missingMedia.Add($name) }
    }

    $imageMatch = [regex]::Match($back, '<img src="([^"]+)"')
    if ($imageMatch.Success) {
        $name = $imageMatch.Groups[1].Value
        $images.Add($name)
        if (-not (@(Invoke-Anki 'getMediaFilesNames' @{ pattern = $name }) -contains $name)) { $missingMedia.Add($name) }
    }
    else { $missingMedia.Add("NO_IMAGE:$($result.target)") }
}

$summary = [PSCustomObject]@{
    validation = $validation
    added = $added
    updated = $updated
    result_count = $results.Count
    unique_front_count = @($fronts | Select-Object -Unique).Count
    unique_image_count = @($images | Select-Object -Unique).Count
    bad_fronts = [string[]]$badFronts
    bad_audio = [string[]]$badAudio
    missing_media = [string[]]@($missingMedia | Select-Object -Unique)
    duplicate_existing_targets = [object[]]$duplicateExisting
    verification_ok = (
        $results.Count -eq $prepared.Count -and
        @($fronts | Select-Object -Unique).Count -eq $prepared.Count -and
        @($images | Select-Object -Unique).Count -eq $prepared.Count -and
        $badFronts.Count -eq 0 -and
        $badAudio.Count -eq 0 -and
        $missingMedia.Count -eq 0 -and
        $duplicateExisting.Count -eq 0
    )
    results = [object[]]$results
}

$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $ResultPath -Encoding UTF8
[void](Invoke-Anki 'sync')
$summary | ConvertTo-Json -Depth 12
