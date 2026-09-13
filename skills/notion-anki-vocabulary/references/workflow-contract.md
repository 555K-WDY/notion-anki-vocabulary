# Workflow contract

## Notion contract

Fetch the live page and data-source schema first. The default database is `词汇整理库`, but the local profile and live property types override this note.

Every word or expression the user adds is Anki-eligible. Learning classifications such as `主动复习`, `认识即可`, and `自然表达修正` are metadata, not exclusion rules. Treat `新收集`, empty Anki status, `待同步`, and legacy `暂不制卡` as pending.

Each database row is a clickable child page. Preserve raw notes and add these sections when correction or interpretation is needed:

1. `原记录`
2. `推测原意`
3. `推荐自然表达`
4. `修改理由或用法`
5. `Anki 提示`
6. `例句`
7. `Anki Note ID` after a verified sync

Keep the homepage limited to the new-content inbox, the vocabulary-database link, and a short numeric sync overview.

## Batch JSON contract

`scripts/sync-anki.ps1` accepts a JSON array. Each row uses:

```json
{
  "index": 1,
  "page_id": "notion-page-id",
  "target": "diligent / be devoted to",
  "meaning": "diligent：勤奋的；be devoted to：致力于、全心投入于",
  "scenario": "一名研究人员每天认真工作，并长期致力于改善公共健康。",
  "examples": [
    "She is a diligent researcher.",
    "She is devoted to improving public health."
  ],
  "image": "C:\\path\\to\\this-item-only.png"
}
```

`example` as a single string is also accepted for compatibility. Separate multiple answer components in `target` with ` / `; the script produces one pronunciation file per component. It produces one audio file per example sentence.

Required card front:

- `常用中文` with the most frequent useful Chinese meaning.
- `情景` with a concrete Chinese recall cue that does not reveal the English answer.

Required card back:

- corrected English target;
- separate target-pronunciation audio;
- natural example sentence or sentences with separate audio;
- one unique, meaning-linked image.

## Example commands

```powershell
& "$SkillRoot\scripts\ensure-anki.ps1"

& "$SkillRoot\scripts\sync-anki.ps1" `
  -DataPath "C:\work\batch.json" `
  -MediaRoot "C:\work\media" `
  -ResultPath "C:\work\result.json" `
  -ValidateOnly

& "$SkillRoot\scripts\sync-anki.ps1" `
  -DataPath "C:\work\batch.json" `
  -MediaRoot "C:\work\media" `
  -ResultPath "C:\work\result.json"
```

## Completion contract

A run is complete only when:

- every processed database target has exactly one intended Anki note;
- each front contains Chinese meaning and scenario;
- each processed item has its own image;
- target and example audios exist as separate files;
- Anki reports every referenced media file;
- Notion stores the Note ID and `已同步` state;
- the final normalized target reconciliation has no unexplained missing, extra, or duplicate items.
