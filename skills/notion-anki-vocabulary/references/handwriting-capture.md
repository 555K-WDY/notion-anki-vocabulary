# 手写英语笔记采集

手写识别只负责把照片变成 **待人工确认草稿**。它不能替代学生核对字迹、上下文或词义，也不会自动写入 Notion 或 Anki。

## 可接受的输入

- 用户直接在 Codex 对话中上传清晰的 JPG、PNG 或 WebP；
- 用户把课堂笔记照片上传到 Notion 的“新增内容”区域，并提供该页面链接；
- Windows 本地文件，使用 `scripts/recognize-handwriting.ps1` 生成 JSON 草稿。

先读取用户最新的 Notion 页面。若连接器可以读取图片本身，使用视觉能力识别；若只能看见附件名称或访问受限，不要假装读到了图片，要求用户将原图直接上传到当前对话或在本机执行脚本。

## Agent 工作流

1. 说明照片会送往用户配置的视觉服务或当前 Codex 视觉能力；提醒不要上传不应发送的个人信息。
2. 保留照片中的英文、中文批注、缩写、拼写和例句为 `原记录`。不清晰之处标记为不确定，绝不静默补造。
3. 对每个候选生成 `推测原意`、`推荐自然表达`、`修改理由或用法`、中文提示、中文情景和自然例句。所有候选初始状态均为 `待人工确认`。
4. 先把照片和草稿放在 Notion 的“新增内容”区域或为每个确认词创建数据库行；将照片链接/附件保留在词条子页，保持可追溯。
5. 只有用户或 Skill 已明确完成核对后，才能使用确认的内容生成批量 JSON、制作专属助记图并同步 Anki。

## Windows 脚本

该脚本是可选的本地通道，需要 `OPENAI_API_KEY` 只存在于当前 PowerShell 进程。它调用 Responses API 的图片输入和 JSON Schema 输出，且设置 `store: false`。不要把 API Key、真实课堂照片或生成草稿提交到 Git。

```powershell
$SkillRoot = Join-Path $env:USERPROFILE '.codex\skills\notion-anki-vocabulary'
& "$SkillRoot\scripts\recognize-handwriting.ps1" `
  -ImagePath 'D:\EnglishNotes\lesson-01.jpg' `
  -OutputPath 'D:\EnglishNotes\lesson-01.handwritten-draft.json'
```

图片仅支持 JPG/JPEG、PNG、WebP，最大 10MB。脚本返回草稿路径和候选数；输出的每项都有 `needs_review: true`，所以它不能被当作已确认的 Anki 批次。

## 审核清单

- [ ] `raw_text` 与照片一致，尤其是拼写、缩写和中文批注；
- [ ] `term` 与课堂语境相符；
- [ ] `uncertainty` 已明确说明所有看不清或推断的地方；
- [ ] 英文释义与例句自然、完整；
- [ ] 照片/附件已保留在 Notion 词条或新增内容页；
- [ ] 只有确认后才迁移到 `词汇整理库` 并同步 Anki。
