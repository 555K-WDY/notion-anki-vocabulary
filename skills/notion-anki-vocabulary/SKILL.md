---
name: notion-anki-vocabulary
description: "Set up and operate a Notion-to-Anki vocabulary pipeline, including handwritten-note photo recognition, first-run Notion database creation, natural-English correction, English scenario-based retrieval prompts, meaning-specific concept images, split pronunciation and example audio, AnkiConnect deduplication, Notion write-back, audits, migration, and scheduled runs. Use when a user wants this vocabulary system even if no Notion page, database, Anki deck, or local profile exists yet. Do not use for unrelated generic Anki imports."
---

# Notion Anki Vocabulary

Set up or run the vocabulary workflow end to end. Treat the user's latest Notion edits as authoritative and never claim a sync succeeded without verification.

## Required resources

- Read `references/workflow-contract.md` before every sync or audit.
- Read `references/onboarding.md` for first use, missing configuration, missing Notion structures, or a missing Anki deck/model.
- Read `references/handwriting-capture.md` before processing a classroom-note photo, an uploaded image, or a Notion page that contains handwritten notes.
- Read `references/migration.md` only when installing, moving, backing up, or restoring the skill.
- Read `references/troubleshooting.md` only when a diagnostic or runtime step fails.
- Use `references/profile.example.json` only as the configuration schema; never edit or publish it with personal IDs.
- Store the active local profile at `%LOCALAPPDATA%\NotionAnkiVocabulary\profile.json` on Windows.
- Use `scripts/configure.ps1` to create or update the local profile.
- Use `scripts/doctor.ps1` before first use and when repairing an installation.
- Use `scripts/ensure-anki.ps1` to test AnkiConnect and, only when needed, start Anki.
- Treat `scripts/sync-anki.ps1` as the repository's legacy Chinese-front/SAPI writer. It does not implement the current scenario-card contract below. Do not use it for a run that claims compliance with this contract; use a writer that implements the complete preflight, media, Note ID, schedule-preservation, and post-write checks in `references/workflow-contract.md`.

## Choose the operating mode

- **Bootstrap:** There is no valid local profile, Notion page/data source, or Anki deck/model. Read `references/onboarding.md` and create only what is missing.
- **Sync:** A valid profile and both services exist. Follow the workflow below.
- **Audit/repair:** The user asks to compare systems or a prior run is uncertain. Run diagnostics, then perform full reconciliation.
- **Migration:** The user is installing or restoring on another computer. Read `references/migration.md`.
- **Handwriting capture:** The user provides a photo, a scan, or a Notion page containing handwritten English. Read `references/handwriting-capture.md`; create a reviewable draft before any database or Anki action.

## Current card contract

Read `references/workflow-contract.md` and `docs/personal-vocabulary-method.md` before designing or synchronizing cards. The user's current structure is the contract; older examples and legacy script templates do not override it.

## Sync workflow

1. Fetch the latest configured Notion homepage and vocabulary data source before making any decision or edit. Inspect the live database schema; do not assume cached property names are still valid.
2. Find all unsynchronised work:
   - homepage or class-note content not yet migrated into the vocabulary database;
   - rows whose category is `新收集`;
   - rows whose Anki property is empty, `待同步`, or the historical value `暂不制卡`;
   - database targets missing from the configured Anki deck during an audit.
3. If there is no new or pending work and no audit is required, report that no organisation is needed. Do not start Anki and do not modify cards.
4. Convert each newly collected word or expression into one database row with its own child page. Keep the homepage short.
5. Preserve the user's original wording, examples, pictures, sound, story, and memory associations. For spelling, collocation, grammar, abbreviation, or fragment problems, infer the most likely intended meaning from the topic, nearby notes, Chinese annotations, and IELTS context. Do not ask for confirmation merely because the source is imperfect.
6. In the child page, record `原记录`, `推测原意`, `推荐自然表达`, `修改理由或用法`, `Anki 提示`, and `例句`. Use only the corrected natural English as the card answer.
7. Prepare every collected item for Anki. Classification changes learning priority only; it never removes sync eligibility unless the user explicitly excludes an item.
8. For ordinary content words and chunks, create or preserve a meaning-specific concept image; inspect it for semantic fit. Do not add a separate scenario image. For function words, use the confirmed cue-label system and do not force an unrelated concrete-object image.
9. Prepare a UTF-8 JSON batch matching `references/workflow-contract.md`. Preserve page IDs and source targets; keep generated media local until upload and verification.
10. Run `scripts/ensure-anki.ps1` with the local profile. Continue only if its JSON output contains `Ready: true`. Report the real error if Anki or AnkiConnect cannot become ready.
11. Run a validate-only preflight with a writer that implements the current card structure, full-target deduplication, unique fronts, independent voice files, and media checks. The bundled `sync-anki.ps1` is legacy and is not a compliant writer for these cards.
12. After a successful preflight, write or update exact targets. Updates must keep Note ID and review schedule. Verify all generated media in Anki, the rendered card fields, and each existing card's schedule; treat duplicate targets or any failed check as incomplete.
13. Only after a verified Anki write, update each Notion row: set the appropriate learning category, `Anki=已同步`, marker, media, and recent-organisation properties; append the Anki Note ID inside the child page. Remove migrated raw material from the homepage only after it is safely represented in the database and Anki.
14. Re-fetch Notion and reconcile normalized database targets against the configured Anki deck. Report database count, deck count, missing targets, unexpected targets, duplicate targets, and pending rows. Do not describe the workflow as fully matched unless all required sets and counts agree.

## Ordinary vocabulary cards

- Front: heading `单词和chunk`; complete target and its own playback; one or two common chunks tied to the scenario, each with its own playback; a divider; a concrete English scenario of two or three lines; then an independent question such as `What would you say?`. Do not put a translation, answer, answer audio, or answer-revealing paraphrase on the front.
- The scenario names people, place, action, change, and the moment that prompts speech. It should make the target expression a natural response, not describe its definition.
- Back: heading `单词和chunk对应的概念实体`; one clear image for the target, optionally a second image only when it concretely represents a related chunk; then `情境下的自然表达`, with the common spoken answer and example sentences. Every listed chunk must occur naturally in the answer. Keep one player per audio on a face.
- Voice: `edge-tts`, `en-GB-SoniaNeural`, `rate='+0%'`; synthesize each complete target, chunk, answer sentence, and example sentence separately. If this voice cannot be produced, report the limitation and leave the item pending instead of silently changing the approved voice.
- Never use a separate scenario image. Preserve useful user-provided concept images. Never reuse an unrelated overview image.

## Function-word cards

Use the seven confirmed short English trigger labels: `but → Important!`, `although → I admit it—but…`, `now as → Listen next!`, `however → Think again!`, `therefore → Take action!`, `otherwise → Warning!`, and `for example → Look here!`. Keep the label on the answer side; the front asks for a quick reaction without revealing it. Explain the function through a typical context and examples. Do not force an unrelated concrete-object image; a relevant visual cue is optional.

## Handwritten-note workflow

1. Fetch the latest referenced Notion page first. If it contains a photo and the current connector can expose image content, use available visual recognition; otherwise request the original image directly rather than claiming it was read.
2. Preserve every visible English fragment, Chinese annotation and uncertain mark as `原记录`. Produce a JSON-style draft with `raw_text`, cautious interpretation, confidence and explicit uncertainty.
3. Mark every photographed candidate `待人工确认` / `needs_review: true`. Do not create a batch, update Notion properties, or touch Anki until the learner has reviewed it.
4. After confirmation, store the photo or its Notion attachment with the corresponding child page, then follow the normal sync workflow. The photo is evidence, not a replacement for the student's own context.
5. The optional Windows helper `scripts/recognize-handwriting.ps1` sends a local image to the configured Responses API with `store: false`. It reads `OPENAI_API_KEY` only from the current process; never put the key in a profile, repository or report.

## Safety and reporting

- Never delete unprocessed or ambiguously migrated user content.
- Keep all user-facing reports in Chinese.
- Distinguish `新增`, `更新`, `已存在`, `失败`, and `待处理` counts.
- On a scheduled run, remain quiet when nothing changed unless the user explicitly requested routine status messages.
- Do not store passwords, connector tokens, or Anki secrets inside this skill.
- Never copy a user's local profile into a Git commit, ZIP release, or public report.
