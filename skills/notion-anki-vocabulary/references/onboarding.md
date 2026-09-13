# First-run onboarding

Use this mode when no local profile exists, the configured Notion objects cannot be fetched, or the Anki deck/model is missing.

## 1. Check capabilities

1. Require a local Windows Codex session for Anki Desktop automation. If the task is running in cloud-only Codex, explain that localhost AnkiConnect is unreachable and continue only with Notion preparation.
2. Check that the Notion connector exposes fetch, create-page, create-database, query, and update operations. Ask the user to connect Notion only when those tools are unavailable or authentication fails.
3. Run `scripts/doctor.ps1`. It reports missing configuration, Anki executable discovery, AnkiConnect reachability, and likely next actions without changing Anki.

## 2. Choose the Notion parent safely

If the user supplied a parent page URL, fetch it and use it. Otherwise create a standalone private page titled `Vocabulary Learning Hub`; do not choose an unrelated shared page. Tell the user where it was created.

Before creating Notion content, read `notion://docs/enhanced-markdown-spec` through the Notion connector.

## 3. Create the minimum Notion structure

Create a page titled `Vocabulary Learning Hub` with this short body:

```markdown
## 新增内容

把课堂、阅读或日常遇到的新词和表达临时记在这里。整理成功后，这部分会被清空。

## 同步概览

尚未进行首次同步。
```

Under that page create a database titled `词汇整理库` with this schema:

```sql
CREATE TABLE (
  "词条" TITLE,
  "主题" MULTI_SELECT('阅读':blue, '写作':green, '口语':orange, '听力':purple, '其他':gray),
  "分类" SELECT('新收集':yellow, '主动复习':red, '认识即可':blue, '自然表达修正':purple),
  "Anki" SELECT('待同步':yellow, '已同步':green, '失败':red),
  "标记" MULTI_SELECT('重点':red, '口语':orange, '易错':yellow, '已纠正':purple),
  "媒体" MULTI_SELECT('图片':blue, '单词音频':green, '例句音频':purple),
  "最近整理" DATE
)
```

Fetch the created page and database, capture the page URL/ID and `collection://` data-source URL, and verify every required property. Do not create a second database if an accessible compatible one already exists.

Create a linked table view on the hub page only if the database is not already visible there. Show `词条`, `主题`, `分类`, and `Anki`; keep the homepage compact.

## 4. Configure local Anki

1. Find Anki in common Windows locations. If it is elsewhere, request only the executable path.
2. If Anki is missing and the user explicitly requested full setup or installation, run `scripts/install-prerequisites.ps1 -InstallAnki -PrepareAnkiConnect`. Otherwise explain the `Anki.Anki` package and ask before installing software.
3. AnkiConnect requires one interactive confirmation in Anki. The script copies official add-on code `2055492159` and opens Anki. Tell the user to choose **Tools > Add-ons > Get Add-ons**, paste the code, install, and restart Anki. Do not sideload unverified add-on files into the profile directory.
4. Run `scripts/configure.ps1` with the verified Notion identifiers and Anki path. If the user has multiple Anki profiles, also set `-AnkiProfile`.
5. Run `scripts/ensure-anki.ps1`. It may start Anki only after pending work or explicit setup has been established.
6. Run `scripts/initialize-anki.ps1`. It creates the configured deck and the dedicated `Notion Anki Vocabulary` model only when absent. Never overwrite an existing model with the same name but incompatible fields; report the mismatch and suggest a different model name.
7. Re-run `scripts/doctor.ps1 -RequireReady` and require `ready: true`.

## 5. Smoke test

Create one clearly labelled test entry only when the user permits test data in their collection. Otherwise use `sync-anki.ps1 -ValidateOnly` with generated temporary files. For a live smoke test, verify the card and media, then delete it only if the user explicitly authorised cleanup.

## 6. Optional schedule

Create a scheduled task only when the user asks. The schedule prompt must invoke `$notion-anki-vocabulary`, point to the local profile, and stay quiet when nothing changed. A skill installation does not itself create a schedule.
