$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$skillRoot = Join-Path $repoRoot 'skills\notion-anki-vocabulary'
$scriptsRoot = Join-Path $skillRoot 'scripts'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('notion-anki-vocabulary-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$mockProcess = $null

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "ASSERTION FAILED: $Message" }
}

try {
    Assert-True (Test-Path -LiteralPath (Join-Path $skillRoot 'SKILL.md')) 'SKILL.md is missing.'
    $skillText = Get-Content -LiteralPath (Join-Path $skillRoot 'SKILL.md') -Raw -Encoding UTF8
    Assert-True ($skillText -match '(?s)^---\s+name:\s*notion-anki-vocabulary\s+description:') 'Skill frontmatter is invalid.'
    foreach ($privateMarker in @(('3bc42652' + '-111a'), ('3266a94a' + '-be1a'), ('D:\New' + ' Folder'), ('C:\Users\' + 'Chris'))) {
        $matches = Get-ChildItem -LiteralPath $repoRoot -Recurse -File | Select-String -SimpleMatch $privateMarker
        Assert-True (@($matches).Count -eq 0) "Private marker was committed: $privateMarker"
    }

    $parseProblems = New-Object System.Collections.Generic.List[string]
    foreach ($script in Get-ChildItem -LiteralPath $repoRoot -Filter '*.ps1' -Recurse) {
        $tokens = $null
        $errors = $null
        [void][Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$errors)
        foreach ($error in $errors) { $parseProblems.Add("$($script.Name): $($error.Message)") }
    }
    Assert-True ($parseProblems.Count -eq 0) ($parseProblems -join '; ')
    Get-Content -LiteralPath (Join-Path $skillRoot 'references\profile.example.json') -Raw -Encoding UTF8 | ConvertFrom-Json | Out-Null
    $onboardingText = Get-Content -LiteralPath (Join-Path $skillRoot 'references\onboarding.md') -Raw -Encoding UTF8
    foreach ($requiredContract in @('Vocabulary Learning Hub', '词汇整理库', '词条', '主题', '分类', 'Anki', '标记', '媒体', '最近整理')) {
        Assert-True ($onboardingText.Contains($requiredContract)) "Notion bootstrap contract is missing: $requiredContract"
    }

    $legacyProfilePath = Join-Path $tempRoot 'legacy-profile.json'
    '{"schema_version":1,"notion":{"page_id":"old","data_source":"collection://old"},"anki":{"executable":"old.exe"},"schedule":{"enabled":false}}' | Set-Content -LiteralPath $legacyProfilePath -Encoding UTF8
    & (Join-Path $scriptsRoot 'configure.ps1') -ProfilePath $legacyProfilePath -AnkiProfile 'Migrated Profile' | Out-Null
    $migratedProfile = Get-Content -LiteralPath $legacyProfilePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True ($migratedProfile.anki.profile -eq 'Migrated Profile' -and $migratedProfile.anki.deck -eq 'Vocabulary::Active') 'Legacy profile fields were not upgraded.'

    $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
    $listener.Start(); $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port; $listener.Stop()
    $statePath = Join-Path $tempRoot 'mock-state.json'
    $python = (Get-Command python -ErrorAction Stop).Source
    $mockProcess = Start-Process -FilePath $python -ArgumentList @((Join-Path $PSScriptRoot 'mock_ankiconnect.py'), '--port', $port, '--state', $statePath) -PassThru -WindowStyle Hidden
    $url = "http://127.0.0.1:$port"
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        try {
            $body = @{ action = 'version'; version = 6 } | ConvertTo-Json -Compress
            $response = Invoke-RestMethod -Uri $url -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 1
            if ($response.result -eq 6) { $ready = $true; break }
        }
        catch { Start-Sleep -Milliseconds 100 }
    }
    Assert-True $ready 'Mock AnkiConnect did not start.'

    $profilePath = Join-Path $tempRoot 'profile.json'
    $dummyExecutable = (Get-Process -Id $PID).Path
    & (Join-Path $scriptsRoot 'configure.ps1') -ProfilePath $profilePath `
        -NotionPageUrl 'https://www.notion.so/test-page' -NotionPageId '11111111-1111-1111-1111-111111111111' `
        -NotionDataSource 'collection://22222222-2222-2222-2222-222222222222' `
        -AnkiExecutable $dummyExecutable -AnkiConnectUrl $url | Out-Null
    $doctor = & (Join-Path $scriptsRoot 'doctor.ps1') -ProfilePath $profilePath -SkipAudioCheck -RequireReady | ConvertFrom-Json
    Assert-True $doctor.ready 'Doctor did not report ready in the sandbox.'
    $ensure = & (Join-Path $scriptsRoot 'ensure-anki.ps1') -ProfilePath $profilePath | ConvertFrom-Json
    Assert-True $ensure.Ready 'ensure-anki did not accept the ready mock server.'
    $initialized = & (Join-Path $scriptsRoot 'initialize-anki.ps1') -ProfilePath $profilePath | ConvertFrom-Json
    Assert-True ($initialized.deck_created -and $initialized.model_created) 'Anki deck/model bootstrap was not exercised.'

    $image1 = Join-Path $tempRoot 'diligent.svg'
    $image2 = Join-Path $tempRoot 'committed.svg'
    $svg1 = & (Join-Path $scriptsRoot 'new-mnemonic-svg.ps1') -Cue '每天认真练习' -Emoji '📚' -OutputPath $image1 | ConvertFrom-Json
    $svg2 = & (Join-Path $scriptsRoot 'new-mnemonic-svg.ps1') -Cue '长期投入公益事业' -Emoji '🤝' -OutputPath $image2 -Accent '#2563EB' | ConvertFrom-Json
    Assert-True ($svg1.created -and $svg2.created) 'Fallback mnemonic SVG generation failed.'
    $batch = @(
        [PSCustomObject]@{ index = 1; page_id = 'page-1'; target = 'diligent'; meaning = '勤奋的'; scenario = '一个人每天认真完成学习任务。'; examples = @('She is a diligent student.', 'Diligent practice builds confidence.'); image = $image1 },
        [PSCustomObject]@{ index = 2; page_id = 'page-2'; target = 'devoted / committed'; meaning = '投入的；坚定的'; scenario = '一个人长期投入一项公益事业。'; examples = @('He is devoted to public service.'); image = $image2 }
    )
    $dataPath = Join-Path $tempRoot 'batch.json'
    $batch | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $dataPath -Encoding UTF8
    $validationPath = Join-Path $tempRoot 'validation.json'
    $validation = & (Join-Path $scriptsRoot 'sync-anki.ps1') -ProfilePath $profilePath -DataPath $dataPath -MediaRoot $tempRoot -ResultPath $validationPath -ValidateOnly | ConvertFrom-Json
    Assert-True ($validation.valid -and $validation.unique_image_content_count -eq 2) 'Batch validation failed.'

    $env:NOTION_ANKI_TEST_MODE = '1'
    $firstPath = Join-Path $tempRoot 'first.json'
    $first = & (Join-Path $scriptsRoot 'sync-anki.ps1') -ProfilePath $profilePath -DataPath $dataPath -MediaRoot $tempRoot -ResultPath $firstPath -RunId 'test-first' -AudioMode SilentTest | ConvertFrom-Json
    Assert-True ($first.verification_ok -and $first.added -eq 2 -and $first.updated -eq 0) 'First sync did not add and verify two notes.'
    Assert-True ($first.results[0].example_audio.Count -eq 2) 'Example audio was not split per sentence.'
    Assert-True ($first.results[1].target_audio.Count -eq 2) 'Target audio was not split per answer component.'

    $secondPath = Join-Path $tempRoot 'second.json'
    $second = & (Join-Path $scriptsRoot 'sync-anki.ps1') -ProfilePath $profilePath -DataPath $dataPath -MediaRoot $tempRoot -ResultPath $secondPath -RunId 'test-second' -AudioMode SilentTest | ConvertFrom-Json
    Assert-True ($second.verification_ok -and $second.added -eq 0 -and $second.updated -eq 2) 'Second sync was not idempotent.'
    Assert-True ($first.results[0].note_id -eq $second.results[0].note_id) 'Existing note ID changed during update.'

    $duplicateBatch = @(
        [PSCustomObject]@{ index = 1; target = 'one'; meaning = '一'; scenario = '一'; example = 'One.'; image = $image1 },
        [PSCustomObject]@{ index = 2; target = 'two'; meaning = '二'; scenario = '二'; example = 'Two.'; image = $image1 }
    )
    $duplicatePath = Join-Path $tempRoot 'duplicate.json'
    $duplicateBatch | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $duplicatePath -Encoding UTF8
    $duplicateRejected = $false
    try { & (Join-Path $scriptsRoot 'sync-anki.ps1') -DataPath $duplicatePath -MediaRoot $tempRoot -ValidateOnly 2>$null | Out-Null }
    catch { $duplicateRejected = $_.Exception.Message -match 'reuse identical image content' }
    Assert-True $duplicateRejected 'Identical image reuse was not rejected.'

    $oldLocalAppData = $env:LOCALAPPDATA
    $oldPath = $env:PATH
    $oldFakeSource = $env:FAKE_ANKI_EXE_SOURCE
    try {
        $fakeLocalAppData = Join-Path $tempRoot 'fake-localappdata'
        $fakeBin = Join-Path $tempRoot 'fake-bin'
        New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
        $fakeWinget = Join-Path $fakeBin 'winget.cmd'
        $fakeSource = (Get-Process -Id $PID).Path
        @'
@echo off
mkdir "%LOCALAPPDATA%\Programs\Anki" 2>nul
copy /Y "%FAKE_ANKI_EXE_SOURCE%" "%LOCALAPPDATA%\Programs\Anki\anki.exe" >nul
exit /b 0
'@ | Set-Content -LiteralPath $fakeWinget -Encoding ASCII
        $env:LOCALAPPDATA = $fakeLocalAppData
        $env:PATH = $fakeBin + [IO.Path]::PathSeparator + $oldPath
        $env:FAKE_ANKI_EXE_SOURCE = $fakeSource
        $prereqProfile = Join-Path $tempRoot 'prereq-profile.json'
        $prereq = & (Join-Path $scriptsRoot 'install-prerequisites.ps1') -InstallAnki -WingetExecutable $fakeWinget -ProfilePath $prereqProfile -Confirm:$false | ConvertFrom-Json
        Assert-True ($prereq.anki_installed_now -and $prereq.anki_found) 'Missing-Anki installation branch did not complete in the sandbox.'
        Assert-True (Test-Path -LiteralPath $prereq.anki_executable -PathType Leaf) 'Sandbox Anki executable was not created.'
    }
    finally {
        $env:LOCALAPPDATA = $oldLocalAppData
        $env:PATH = $oldPath
        if ($null -eq $oldFakeSource) { Remove-Item Env:FAKE_ANKI_EXE_SOURCE -ErrorAction SilentlyContinue } else { $env:FAKE_ANKI_EXE_SOURCE = $oldFakeSource }
    }

    $installRoot = Join-Path $tempRoot 'installed-skills'
    & (Join-Path $repoRoot 'install.ps1') -DestinationRoot $installRoot | Out-Null
    Assert-True (Test-Path -LiteralPath (Join-Path $installRoot 'notion-anki-vocabulary\SKILL.md')) 'Manual installer did not install the skill.'

    $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert-True (@($state.notes.PSObject.Properties).Count -eq 2) 'Mock server contains an unexpected note count.'
    Assert-True ($state.media_names.Count -eq 8) 'Mock server contains an unexpected media count.'

    [PSCustomObject]@{
        passed = $true
        tests = @('structure', 'privacy markers', 'PowerShell syntax', 'Notion bootstrap contract', 'legacy profile upgrade', 'profile configuration', 'doctor', 'connection', 'deck/model bootstrap', 'fallback mnemonic images', 'batch validation', 'first sync', 'split audio', 'unique images', 'idempotent update', 'duplicate-image rejection', 'missing-Anki installer branch', 'manual install')
        sandbox = $tempRoot
        mock_note_count = @($state.notes.PSObject.Properties).Count
        mock_media_count = $state.media_names.Count
    } | ConvertTo-Json -Depth 6
}
finally {
    Remove-Item Env:NOTION_ANKI_TEST_MODE -ErrorAction SilentlyContinue
    if ($null -ne $mockProcess -and -not $mockProcess.HasExited) { Stop-Process -Id $mockProcess.Id -Force }
}
