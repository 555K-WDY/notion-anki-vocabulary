# Migration to another computer

## Copy the skill

Prefer installing directly from the public GitHub repository with `$skill-installer`. A manual clone or ZIP download must preserve the entire `skills/notion-anki-vocabulary` folder. Do not copy only `SKILL.md`; the scripts and references are part of the workflow.

The skill installer uses:

```text
%USERPROFILE%\.codex\skills\notion-anki-vocabulary
```

Codex may also discover manually authored personal skills at:

```text
%USERPROFILE%\.agents\skills\notion-anki-vocabulary
```

Use one location, not both, to avoid duplicate skill entries. Restart Codex if the skill is not available on the next turn.

## Reconnect external services

1. Install Codex and sign in.
2. Enable and authorize the Notion connector. Authentication is deliberately not stored in the skill. If restoring the same system, share the existing page/database with the connection; otherwise invoke bootstrap mode to create them.
3. Install Anki and the AnkiConnect add-on. Keep AnkiConnect listening on `127.0.0.1:8765`, or update the profile and script arguments.
4. Copy the Anki collection and media through Anki's supported sync/export method if historical cards must move too. The skill folder does not contain the Anki collection.
5. Run `scripts/configure.ps1` to create the new computer's local profile. Never edit `references/profile.example.json` with personal values.
6. Test the connection with `scripts/ensure-anki.ps1`, then run `scripts/sync-anki.ps1 -ValidateOnly` on a small batch before enabling the daily schedule.
7. Recreate the 07:00 Asia/Shanghai scheduled task and have its prompt explicitly invoke `$notion-anki-vocabulary` and follow the configured profile.

## GitHub installation

Invoke `$skill-installer` with the repository and skill path:

```text
$skill-installer install from 555K-WDY/notion-anki-vocabulary, path skills/notion-anki-vocabulary
```

The installer makes the skill available on the next turn. Then invoke:

```text
$notion-anki-vocabulary initialize my vocabulary system
```

## Portable archive

Create a zip file with:

```powershell
& "$SkillRoot\scripts\export-skill.ps1" -DestinationPath "C:\backup\notion-anki-vocabulary-skill.zip"
```

On the new computer, extract the archive so that `SKILL.md` sits directly inside the final `notion-anki-vocabulary` folder.
