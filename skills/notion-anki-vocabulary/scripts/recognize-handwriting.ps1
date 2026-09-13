param(
    [Parameter(Mandatory = $true)][string]$ImagePath,
    [string]$OutputPath,
    [string]$Model = 'gpt-5.2',
    [string]$Endpoint = 'https://api.openai.com/v1/responses'
)

$ErrorActionPreference = 'Stop'

function Get-ImageMimeType([string]$Path) {
    switch ([IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.jpg' { return 'image/jpeg' }
        '.jpeg' { return 'image/jpeg' }
        '.png' { return 'image/png' }
        '.webp' { return 'image/webp' }
        default { throw '仅支持 JPG、JPEG、PNG 或 WebP 图片。' }
    }
}

function Get-ResponseOutputText($Response) {
    $parts = New-Object System.Collections.Generic.List[string]
    foreach ($item in @($Response.output)) {
        if ([string]$item.type -ne 'message') { continue }
        foreach ($content in @($item.content)) {
            if ([string]$content.type -eq 'output_text' -and $null -ne $content.text) {
                $parts.Add([string]$content.text)
            }
        }
    }
    $text = $parts -join ''
    if (-not $text) { throw '视觉服务没有返回可读取的结构化文本。' }
    return $text
}

if (-not $env:OPENAI_API_KEY) {
    throw '未设置 OPENAI_API_KEY。手写识别是可选功能；请只在当前 PowerShell 会话中配置该变量，且不要把密钥写进 profile 或仓库。'
}

$resolvedImagePath = (Resolve-Path -LiteralPath $ImagePath -ErrorAction Stop).Path
$file = Get-Item -LiteralPath $resolvedImagePath
if ($file.Length -gt 10MB) { throw '图片超过 10MB。请先裁剪或压缩课堂笔记照片。' }
$mimeType = Get-ImageMimeType $resolvedImagePath
$dataUrl = "data:$mimeType;base64,$([Convert]::ToBase64String([IO.File]::ReadAllBytes($resolvedImagePath)))"

if (-not $OutputPath) {
    $baseName = [IO.Path]::GetFileNameWithoutExtension($resolvedImagePath)
    $OutputPath = Join-Path (Split-Path -Parent $resolvedImagePath) "$baseName.handwritten-draft.json"
}
$resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }

$itemSchema = [ordered]@{
    type = 'object'
    additionalProperties = $false
    properties = [ordered]@{
        raw_text = @{ type = 'string' }
        term = @{ type = 'string' }
        inferred_meaning = @{ type = 'string' }
        suggested_definition = @{ type = 'string' }
        suggested_example = @{ type = 'string' }
        chinese_hint = @{ type = 'string' }
        scenario = @{ type = 'string' }
        correction_reason = @{ type = 'string' }
        uncertainty = @{ type = 'string' }
        confidence = @{ type = 'number' }
    }
    required = @('raw_text', 'term', 'inferred_meaning', 'suggested_definition', 'suggested_example', 'chinese_hint', 'scenario', 'correction_reason', 'uncertainty', 'confidence')
}
$schema = [ordered]@{
    type = 'object'
    additionalProperties = $false
    properties = [ordered]@{
        source_summary = @{ type = 'string' }
        items = @{ type = 'array'; items = $itemSchema }
    }
    required = @('source_summary', 'items')
}
$instructions = @'
你正在阅读一张中国学生的英语课堂手写笔记照片。只识别清晰可见的英文单词、短语、例句、中文批注和上下文；绝不把看不清的内容伪造成确定事实。每个项目保留 raw_text，并根据同一页上下文给出谨慎的 inferred_meaning、自然英文释义和例句建议。term 不确定时填入最可能的候选，并在 uncertainty 中说明原因。所有内容只是待人工确认的草稿，不是最终词库，也不要输出敏感的个人信息。
'@
$payload = [ordered]@{
    model = $Model
    store = $false
    input = @(@{
        role = 'user'
        content = @(
            @{ type = 'input_text'; text = $instructions },
            @{ type = 'input_image'; image_url = $dataUrl; detail = 'high' }
        )
    })
    text = @{ format = @{ type = 'json_schema'; name = 'handwritten_vocabulary_draft'; strict = $true; schema = $schema } }
}

try {
    $json = $payload | ConvertTo-Json -Depth 30 -Compress
    $response = Invoke-RestMethod -Uri $Endpoint -Method Post -ContentType 'application/json; charset=utf-8' `
        -Headers @{ Authorization = "Bearer $($env:OPENAI_API_KEY)" } -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 90
}
catch {
    throw "手写识别请求失败：$($_.Exception.Message)"
}
if ($response.error) { throw "手写识别服务返回错误：$($response.error.message)" }

try { $recognized = Get-ResponseOutputText $response | ConvertFrom-Json }
catch { throw "手写识别返回的结构化结果无法解析：$($_.Exception.Message)" }

$candidates = @($recognized.items | ForEach-Object {
    [PSCustomObject]@{
        raw_text = [string]$_.raw_text
        term = [string]$_.term
        inferred_meaning = [string]$_.inferred_meaning
        suggested_definition = [string]$_.suggested_definition
        suggested_example = [string]$_.suggested_example
        chinese_hint = [string]$_.chinese_hint
        scenario = [string]$_.scenario
        correction_reason = [string]$_.correction_reason
        uncertainty = [string]$_.uncertainty
        confidence = [double]$_.confidence
        needs_review = $true
    }
})
$draft = [PSCustomObject]@{
    schema_version = 1
    source_type = 'handwritten-photo'
    source_file = [IO.Path]::GetFileName($resolvedImagePath)
    source_summary = [string]$recognized.source_summary
    generated_at = [DateTime]::UtcNow.ToString('o')
    needs_review = $true
    candidates = $candidates
}
$draft | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedOutputPath -Encoding UTF8
[PSCustomObject]@{
    draft_path = $resolvedOutputPath
    candidate_count = $candidates.Count
    needs_review = $true
    next_step = '请逐项核对草稿，再将确认的内容写入 Notion 词汇整理库。该脚本不会自动写入 Notion 或 Anki。'
} | ConvertTo-Json -Depth 6
