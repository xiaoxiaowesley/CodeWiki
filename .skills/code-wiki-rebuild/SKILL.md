---
name: code-wiki-rebuild
description: >
  Archive existing wiki knowledge and rebuild from scratch, or restore from a previous archive.
  Use when the wiki has drifted too far from source code and incremental ingest won't suffice,
  the user wants to start fresh, snapshot before a major refactor, or roll back to an older
  state. Triggers on "rebuild the wiki", "start over", "archive and rebuild", "restore from
  archive", "nuke and repave", "clean rebuild". Resets `.git-state.json` so the next ingest
  treats the repo as new.
---

# Code Wiki Rebuild — Archive, Rebuild, Restore

You are performing a destructive operation on the code wiki. **Always archive first, always confirm with the user before proceeding.**

## Before You Start

1. **Resolve config** — follow the Config Resolution Protocol in `code-wiki/SKILL.md` (walk up CWD for `.env` → `~/.code-wiki/config` → prompt setup). This yields `CODE_WIKI_OUTPUT_PATH` and optional QMD settings such as `QMD_WIKI_COLLECTION`.
2. **Optional repo argument.** If the user names a specific repo or wiki, resolve `CODE_WIKI_OUTPUT_PATH` to point at that wiki. Otherwise use the resolved default.
3. **Read `.manifest.json`** at the wiki root to understand current state — total pages, last ingested commit, ingested repo path.
4. **Read `.git-state.json`** if present — note the last synced commit; you'll archive and reset it.
5. **Confirm the user's intent.** This skill supports three modes:
   - **Archive only** — snapshot current wiki, no rebuild
   - **Archive + Rebuild** — snapshot, then clear the wiki and reset state for a full re-ingest
   - **Restore** — bring back a previous archive

## The Archive System

Archives live at `$CODE_WIKI_OUTPUT_PATH/_archives/`. Each archive is a timestamped directory containing a full copy of the wiki state at that point, including the eight category directories used by code wikis.

```
$CODE_WIKI_OUTPUT_PATH/
├── _archives/
│   ├── 2026-05-26T10-30-00Z/
│   │   ├── archive-meta.json
│   │   ├── 01-overview/
│   │   ├── 02-architecture/
│   │   ├── 03-modules/
│   │   ├── 04-flows/
│   │   ├── 05-config/
│   │   ├── 06-testing/
│   │   ├── 07-ops/
│   │   ├── 08-decisions/
│   │   ├── index.md
│   │   ├── log.md
│   │   ├── .manifest.json
│   │   └── .git-state.json
│   └── 2026-04-15T08-00-00Z/
│       └── ...
├── 01-overview/          ← live wiki
├── 02-architecture/
├── 03-modules/
├── 04-flows/
├── 05-config/
├── 06-testing/
├── 07-ops/
├── 08-decisions/
├── schema/               ← preserved across rebuilds
├── index.md
├── log.md
├── .manifest.json
└── .git-state.json
```

### archive-meta.json

```json
{
  "archived_at": "2026-05-26T10:30:00Z",
  "reason": "rebuild",
  "total_pages": 87,
  "wiki_path": "/Users/name/code-wikis/my-repo",
  "repo_path": "/Users/name/projects/my-repo",
  "last_ingested_commit": "abc1234def5678",
  "categories": ["01-overview", "02-architecture", "03-modules", "04-flows", "05-config", "06-testing", "07-ops", "08-decisions"],
  "manifest_snapshot": ".manifest.json",
  "git_state_snapshot": ".git-state.json"
}
```

## Mode 1: Archive Only

When the user wants to snapshot the current state without rebuilding.

### Steps:

1. Create archive directory: `_archives/YYYY-MM-DDTHH-MM-SSZ/`
2. Copy all eight category directories (`01-overview/` … `08-decisions/`), `index.md`, `log.md`, `.manifest.json`, and `.git-state.json` into the archive.
3. Write `archive-meta.json` with reason `"snapshot"`, capturing `total_pages`, `repo_path`, and `last_ingested_commit`.
4. Append to `log.md`:
   ```
   - [TIMESTAMP] ARCHIVE reason="snapshot" pages=87 destination="_archives/2026-05-26T10-30-00Z"
   ```
5. Optionally refresh QMD if `log.md` is indexed and `QMD_WIKI_COLLECTION` is configured (see "QMD Refresh After Live Wiki Changes").
6. Report: "Archived 87 pages to `_archives/2026-05-26T10-30-00Z`. Live wiki is untouched."

## Mode 2: Archive + Rebuild

When the user wants to start fresh. This is the full sequence.

### Step 1: Archive current state

Same as Mode 1 above, but with reason `"rebuild"`.

### Step 2: Confirm with the user

Show what's about to be cleared (page count per category, last ingested commit). Get explicit confirmation before proceeding.

### Step 3: Clear the live wiki

Remove all content from the eight category directories. Reset the root files. **Preserve:**

- `_archives/` (obviously)
- `schema/` — including `schema/wiki-structure.yaml`; this defines the structure and survives rebuilds
- `.env` (if present at the wiki root)

Specifically:

- Empty each of `01-overview/` … `08-decisions/` (remove all `.md` files but keep the directories).
- Reset `index.md` to the empty template (header + empty per-category sections).
- Reset `log.md` to a single rebuild entry.
- Reset `.manifest.json` to `{}` or an empty schema-shaped object — it'll be repopulated by the next ingest.
- **Delete `.git-state.json`** so the next ingest treats the repo as new and processes all files. This is the key state reset for code wikis.

### Step 4: Log the rebuild

Append to the freshly reset `log.md`:

```
- [TIMESTAMP] REBUILD archived_to="_archives/2026-05-26T10-30-00Z" previous_pages=87 git_state_reset=true
```

### Step 5: Refresh QMD and report

Refresh QMD after clearing (see "QMD Refresh After Live Wiki Changes"). Report the wiki is ready for full re-ingest and prompt the user:

> The wiki has been cleared and `.git-state.json` reset. Run `/code-wiki-ingest` against the source repo to rebuild the wiki from scratch.

**Important:** Don't run the ingest yourself. Let the user choose when and how (full vs. targeted at specific modules).

## Mode 3: Restore from Archive

When the user wants to roll back to a previous state.

### Step 1: List available archives

Read `_archives/`. For each archive read `archive-meta.json` and present:

```markdown
## Available Archives

| Date                | Reason     | Pages | Repo Commit  |
|---------------------|------------|-------|--------------|
| 2026-05-26 10:30 UTC| rebuild    | 87    | abc1234      |
| 2026-04-15 08:00 UTC| snapshot   | 65    | 9f8e7d6      |
| 2026-03-01 14:12 UTC| pre-restore| 52    | 1a2b3c4      |
```

### Step 2: Confirm which archive to restore

Ask the user which archive. Warn that restoring will overwrite the current live wiki.

### Step 3: Archive current state first (safety net)

Before restoring, archive the current state with reason `"pre-restore"` so nothing is lost.

### Step 4: Restore

1. Clear the live wiki (same as Mode 2, Step 3 — but **do not** delete `.git-state.json` yet).
2. Copy all eight category directories from the chosen archive back into the live wiki.
3. Restore `index.md`, `log.md`, and `.manifest.json` from the archive.
4. **Restore `.git-state.json`** from the archive so future incremental ingests resume from the archived commit. If the archive lacks `.git-state.json` (older archive format), delete the live one and warn the user the next ingest will be treated as full.
5. Append to `log.md`:
   ```
   - [TIMESTAMP] RESTORE from="_archives/2026-04-15T08-00-00Z" pages_restored=65 git_state_restored=true
   ```

### Step 5: Refresh QMD and report

Refresh QMD after restore (see "QMD Refresh After Live Wiki Changes"). Tell the user what was restored, which commit the wiki is now synced to, and suggest running `/code-wiki-lint` to check the restored state for any dangling links or stale frontmatter.

## QMD Refresh After Live Wiki Changes

QMD is a search index, not the source of truth. If QMD refresh fails, do not roll back archive, rebuild, or restore work; report the failure and leave the markdown wiki intact.

**GUARD: If `$QMD_WIKI_COLLECTION` is empty or unset, skip this step.**

When to run:

| Mode | Refresh QMD? | Reason |
|---|---|---|
| Archive only | Optional | Live wiki content is unchanged except `log.md`; refresh if `log.md` is indexed and QMD is configured. |
| Archive + Rebuild | Required after clearing live wiki | QMD must forget deleted pages or it will return stale search results. The next ingest will refresh again as pages are recreated. |
| Restore | Required after restore | The live wiki was replaced with archive content, so QMD must match the restored state. |

Refresh currently requires the local QMD CLI. Use `$QMD_CLI` if set; otherwise use `qmd`. If the CLI is unavailable, report `QMD skipped: qmd CLI unavailable`.

```bash
${QMD_CLI:-qmd} update
```

If the output says new hashes need vectors, or if restore replaced live pages and embeddings may be stale, run:

```bash
${QMD_CLI:-qmd} embed
```

Verify the wiki collection reflects the operation:

```bash
${QMD_CLI:-qmd} ls "$QMD_WIKI_COLLECTION"
```

For restore, also verify one restored page if the archive has a known page path:

```bash
${QMD_CLI:-qmd} get "qmd://$QMD_WIKI_COLLECTION/<restored-page>.md" -l 5
```

Record QMD refresh in the final report as one of:

- `QMD refreshed: update + embed + verified`
- `QMD refreshed: update only + verified`
- `QMD skipped: QMD_WIKI_COLLECTION unset`
- `QMD skipped: archive-only live content unchanged`
- `QMD skipped: qmd CLI unavailable`
- `QMD failed: <short error summary>`

## Operational Flow Summary

Every invocation of this skill walks the same outer loop:

1. **Config Resolution** — locate `CODE_WIKI_OUTPUT_PATH`.
2. **Locate wiki root** — confirm the directory exists and is initialized (has `schema/` and `index.md`).
3. **Determine mode** — ask the user if not specified (Archive Only / Archive + Rebuild / Restore).
4. **Execute with confirmation** — show what will change before any destructive step.
5. **QMD Refresh** — only if `QMD_WIKI_COLLECTION` is configured and the mode requires it.
6. **Log the operation** — append a structured entry to `log.md`.

## Safety Rules

1. **Always archive before destructive operations.** No exceptions. Even Restore archives the current state first as a safety net.
2. **Always confirm with the user** before clearing the live wiki or overwriting it from an archive.
3. **Never delete archives** unless the user explicitly asks. Archives are cheap insurance.
4. **Preserve `schema/`.** The `schema/wiki-structure.yaml` file defines the wiki's structure and must survive rebuilds untouched.
5. **Preserve `.manifest.json` semantics.** During rebuild it is *reset* (not deleted from the schema), so the next ingest can repopulate it. During restore it is *replaced* from the archive.
6. **Reset `.git-state.json` on rebuild, restore it on restore.** This is what makes the next ingest behave correctly — full re-ingest after rebuild, incremental from the archived commit after restore.
7. **Never touch the source repository.** This skill operates only on the wiki output directory. The repo at `repo_path` is read-only ground truth.
8. If something goes wrong mid-rebuild, the archive is there. Tell the user they can restore from `_archives/`.
