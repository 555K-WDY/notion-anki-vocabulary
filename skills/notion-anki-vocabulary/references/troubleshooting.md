# Troubleshooting

Use the first matching section. Preserve exact error text in the report.

## Skill is not discovered

- Confirm `SKILL.md` is directly inside the installed `notion-anki-vocabulary` folder.
- Install through `$skill-installer` or copy to `$CODEX_HOME/skills/notion-anki-vocabulary` (normally `%USERPROFILE%\.codex\skills\...`).
- Avoid installing the same skill in both `.agents\skills` and `.codex\skills`.
- Restart Codex if it does not appear on the next turn.

## Notion is unavailable

- Fetch `self` through the Notion connector to distinguish not connected, insufficient plan, disabled tool, and missing page access.
- Ask the user to connect Notion or share the intended parent page with the connector.
- Never ask for or store a raw Notion integration secret in the profile.
- If a saved page was deleted or access was revoked, bootstrap a new page only after explaining that the old location is unavailable.

## Notion schema drift

- Fetch the live data source before editing.
- Add missing safe properties; do not drop or rename user properties automatically.
- If a required property has an incompatible type, create a new non-conflicting property and update the local profile/schema mapping rather than destroying data.

## Anki cannot be found

- Pass the full executable path to `configure.ps1 -AnkiExecutable`.
- Common paths are `%LOCALAPPDATA%\Programs\Anki\anki.exe` and `%PROGRAMFILES%\Anki\anki.exe`.
- Microsoft Store packaging or custom portable installs may require manual selection.

## AnkiConnect is unreachable

- Confirm Anki Desktop is running and AnkiConnect is installed and enabled.
- Confirm the configured URL is `http://127.0.0.1:8765` unless the user deliberately changed it.
- Restart Anki after installing or changing the add-on.
- On Anki's first launch, finish language/profile selection before waiting for AnkiConnect.
- Do not weaken AnkiConnect origin or network security settings merely to make localhost calls work.
- If the user configured an AnkiConnect API key, read it only from the process-local `ANKI_CONNECT_API_KEY` environment variable. Never save it in the profile or repository.

## Model or field mismatch

- The default dedicated model is `Notion Anki Vocabulary` with fields `Front` and `Back`.
- `initialize-anki.ps1` creates it only when absent.
- If the name exists with other fields, choose a new model name or explicitly configure the existing field names. Never overwrite templates or fields silently.

## Audio generation fails

- This release supports Windows SAPI voices. Run in Windows PowerShell or PowerShell 7 on Windows.
- Confirm at least one English Windows speech voice is installed.
- Change `-VoicePattern` if the English voice has another name.
- Treat missing audio as an incomplete sync; do not mark Notion as synced.

## Image generation is unavailable

- Run `new-mnemonic-svg.ps1` with a concrete meaning-specific Chinese cue and suitable emoji.
- Use a different cue/image for every target and still run duplicate-image validation.

## Images are duplicated or missing

- Generate or preserve one image per meaning.
- `sync-anki.ps1 -ValidateOnly` rejects identical image bytes within a batch.
- Use local PNG, JPG, GIF, WEBP, or SVG files. Do not reference expiring web URLs in cards.

## Duplicate cards

- The script normalizes the first bold target on the back and updates an exact match.
- If multiple existing notes have the same normalized target, it updates one but returns `verification_ok: false` with all duplicate note IDs.
- Do not delete duplicates automatically. Report them for deliberate cleanup.

## Partial failure

- Keep affected Notion rows at `待同步` or set them to `失败` with the real error.
- Re-run the same deterministic batch after fixing the cause; stable media names make retries safe.
- Update Notion to `已同步` only for rows whose Anki Note ID and media were verified.
