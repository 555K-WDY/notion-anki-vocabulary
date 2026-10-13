# Workflow contract

This contract defines the current scenario-card workflow. User-specific pages, IDs, profiles, and vocabulary remain local and are never copied into this public repository.

## Notion contract

Fetch the live homepage and data-source schema before making decisions or edits. The live property types override examples in this file.

Every new word, chunk, or expression is eligible for Anki unless the learner explicitly excludes it. Learning categories such as `主动复习`, `认识即可`, and `自然表达修正` indicate priority; they do not remove sync eligibility. Treat `新收集`, empty Anki status, `待同步`, and legacy `暂不制卡` as pending.

Use a clickable child page for each target. Preserve original wording, examples, images, audio, stories, and personal associations. Where the source needs correction, retain distinct sections:

1. `原记录`
2. `推测原意`
3. `推荐自然表达`
4. `修改理由或用法`
5. `Anki 提示`
6. `例句`
7. `Anki Note ID` only after verified sync

Keep the homepage short: a dedicated `新增单词chunk放置` inbox, a vocabulary-database link, and a compact sync overview.

## Batch schema

A batch is a UTF-8 JSON array. Example ordinary item:

```json
{
  "index": 1,
  "page_id": "notion-page-id",
  "source_target": "be devoted to",
  "target": "be devoted to",
  "meaning": "致力于；全心投入于",
  "kind": "ordinary",
  "chunks": ["be devoted to improving public health"],
  "scenario": [
    "Your colleague Mia has just joined a public-health project at the clinic.",
    "When the team asks why she will stay late, she explains that the work matters deeply to her."
  ],
  "question": "What would you say?",
  "answer": "I'm devoted to improving public health.",
  "examples": ["She is devoted to helping families in her community."],
  "image": "C:\\work\\media\\be-devoted-to.png"
}
```

For a function word, use `kind: "trigger"`, preserve the confirmed `trigger` label, and provide a typical scenario, explanation, examples, and target audio. Do not invent a concrete-object image when the function has no meaningful entity.

## Ordinary card contract

### Front

- A clear heading: `单词和chunk`.
- The complete target word or chunk with independent playback.
- One or two common chunks tied strongly to the scenario, each with independent playback.
- A divider, then a concrete English scenario, normally two or three lines.
- The scenario identifies people, place, action, change, and the moment that prompts speech.
- A separate recall question such as `What would you say?`.
- Do not show the answer, a Chinese/English definition that gives it away, or answer audio.

### Back

- Heading: `单词和chunk对应的概念实体`.
- A clear, target-specific concept image. A second image is allowed only when it directly depicts a related chunk. There is no separate scenario image.
- Heading: `情境下的自然表达`.
- The likely common spoken response to the exact front scenario, with useful examples and independent audio.
- Each front chunk must occur naturally in the back answer.
- One audio file has only one player on each face.

## Function-word contract

Use these seven learner-confirmed labels as retrieval cues:

| Target | Cue |
|---|---|
| `but` | `Important!` |
| `although` | `I admit it—but…` |
| `now as` | `Listen next!` |
| `however` | `Think again!` |
| `therefore` | `Take action!` |
| `otherwise` | `Warning!` |
| `for example` | `Look here!` |

The front cues a quick reaction without revealing the label. The back gives the label, the function in context, and example sentences. Keep labels short. Do not force these items into ordinary concrete-entity image cards.

## Audio and image rules

- Approved voice: `edge-tts`, `en-GB-SoniaNeural`, `rate='+0%'`.
- Generate complete audio independently for the target, each chunk, each answer sentence, and each example sentence. Keep natural stress, reduction, linking, and pauses.
- Audio must match the current text. Regenerate it when the expression changes.
- Prefer inspected, meaning-specific concept images; preserve useful learner-provided images. The image must not be a generic overview reused across unrelated targets.
- Store files in Anki media and verify every referenced name. A local file alone does not prove upload success.
- If the approved voice or media service is unavailable, report the actual issue and keep the item pending; do not silently substitute a voice or mark it synced.

## Writer and validation requirements

The repository's bundled `scripts/sync-anki.ps1` is a legacy Chinese-front/SAPI implementation. It does not implement this contract. Do not use it to claim a current scenario-card sync. A writer for this contract must provide equivalent validate-only and write modes.

Before writing:

1. Confirm AnkiConnect returns `Ready: true` through `scripts/ensure-anki.ps1`.
2. Confirm the live profile's deck, model, and fields.
3. Deduplicate on the complete normalized target, not only its first component. If more than one existing match is found, stop for audit; do not arbitrarily choose or delete.
4. Validate the whole batch, scenario-answer fit, front answer leakage, chunk usage, unique target, image semantics, generated audio, and all local files.
5. Snapshot existing Note IDs and card schedules.

After writing:

1. Confirm exact expected note count and rendered fields, including no answer leakage and no duplicate player.
2. Confirm each referenced image and audio exists in Anki media.
3. Update an exact existing note in place. Preserve its Note ID and review schedule; never delete and recreate it to refresh content.
4. Only after Anki/media verification, write `Anki=已同步`, category, media, date, and Note ID back to Notion.
5. Re-fetch changed pages and the relevant database view.
6. Compare normalized Notion targets with the configured deck. Report database rows, normalized targets, deck notes, missing, extra, duplicate, ambiguous, and pending targets. Historical explained differences may remain, but must be listed; do not say the sets fully match while unexplained differences remain.
7. Clear only processed homepage content after all associated Notion and Anki checks pass. Retain every item that failed or remains ambiguous.

## Rationale and evidence

The design applies retrieval practice and spacing, uses cues related to intended language use, stores natural multiword units, and adds meaning-specific imagery and separate sound. Research supports retrieval practice and distributed practice for retention; transfer depends on cue/task match; imagery and extra modalities are reasons to test relevant cues, not a promise that more media always improves learning. See [`docs/personal-vocabulary-method.md`](../../../docs/personal-vocabulary-method.md) for the reasoning, references, and limits.
