---
name: notion-anki-vocabulary
description: "Set up and operate a Notion-to-Anki vocabulary pipeline, including handwritten-note photo recognition, first-run Notion database creation, natural-English correction, Chinese scenario prompts, per-item mnemonic images, split pronunciation and example audio, AnkiConnect deduplication, Notion write-back, audits, migration, and scheduled runs. Use when a user wants this vocabulary system even if no Notion page, database, Anki deck, or local profile exists yet. Do not use for unrelated generic Anki imports."
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
- Use `scripts/sync-anki.ps1` for deterministic Anki creation, updating, audio generation, media upload, and post-write verification.

## Choose the operating mode

- **Bootstrap:** There is no valid local profile, Notion page/data source, or Anki deck/model. Read `references/onboarding.md` and create only what is missing.
- **Sync:** A valid profile and both services exist. Follow the workflow below.
- **Audit/repair:** The user asks to compare systems or a prior run is uncertain. Run diagnostics, then perform full reconciliation.
- **Migration:** The user is installing or restoring on another computer. Read `references/migration.md`.
- **Handwriting capture:** The user provides a photo, a scan, or a Notion page containing handwritten English. Read `references/handwriting-capture.md`; create a reviewable draft before any database or Anki action.

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
8. Create one meaning-specific mnemonic image for each item. Prefer the available image generation capability and inspect the output. If image generation is unavailable, use `scripts/new-mnemonic-svg.ps1` with a meaning-specific cue and emoji. Never reuse one overview image across unrelated cards. Preserve any useful user-provided image instead of replacing it needlessly.
9. Build a UTF-8 JSON batch matching the schema in `references/workflow-contract.md`. Put generated images in a local media directory.
10. Run `scripts/ensure-anki.ps1` with the local profile. Continue only if its JSON output contains `Ready: true`. Report the real error if Anki or AnkiConnect cannot become ready.
11. First run `scripts/sync-anki.ps1 -ValidateOnly`; then run it without that switch. It must update an exact existing target rather than creating a duplicate. It generates separate audio for each answer component and for each example sentence.
12. Inspect the result JSON. Require correct counts, unique fronts, one unique image per processed item, separate target/example audio, and zero missing media. Treat duplicate existing targets or any failed check as incomplete.
13. Only after a verified Anki write, update each Notion row: set the appropriate learning category, `Anki=已同步`, marker, media, and recent-organisation properties; append the Anki Note ID inside the child page. Remove migrated raw material from the homepage only after it is safely represented in the database and Anki.
14. Re-fetch Notion and reconcile normalized database targets against the configured Anki deck. Report database count, deck count, missing targets, unexpected targets, duplicate targets, and pending rows. Do not describe the workflow as fully matched unless all required sets and counts agree.

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
