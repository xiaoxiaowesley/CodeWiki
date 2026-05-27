---
name: code-wiki-lint
description: >
  Audit and maintain the health of a code wiki. Checks for orphaned pages, broken wikilinks,
  missing frontmatter, stale content, contradictions, and code-wiki sync issues.
  Add --consolidate to switch from report-only to act-and-report mode.
---

# Code Wiki Lint — Health Audit

You are performing a health check on a code wiki generated from a source repository. Your goal is to find and fix structural issues that degrade the wiki's value over time — broken links, orphaned pages, stale content, drift between wiki and code, and schema violations.

**Before scanning anything:** follow the Retrieval Primitives table in `code-wiki/SKILL.md`. Prefer frontmatter-scoped greps and section-anchored reads over full-page reads. On a large code wiki, blindly reading every page is exactly what this framework is built to avoid.

## Before You Start

1. **Resolve config** — follow the Config Resolution Protocol in `code-wiki/SKILL.md` (walk up CWD for `.env` → `~/.code-wiki/config` → prompt setup). This gives `CODE_WIKI_OUTPUT_PATH` (default: `./wiki`) and optional `CODE_WIKI_REPO`, `QMD_WIKI_COLLECTION`, `QMD_CODE_COLLECTION`.
2. **Locate wiki root** — use `CODE_WIKI_OUTPUT_PATH`. If the directory does not exist, abort with: "Wiki not found. Run `code-wiki-ingest` first."
3. **Locate source repo** — optional positional argument; otherwise read `repo_path` from `.git-state.json` at the wiki root; otherwise default to CWD.
4. Read `index.md` for the full page inventory.
5. Read `log.md` for recent activity context.
6. Read `.git-state.json` for `last_ingested_commit` (used by checks 5 and 11).

## Lint Checks

Run these 11 checks in order. Report findings as you go, grouped by severity (Critical / Warning / Info).

### 1. Orphaned Pages (Warning)

Find pages with zero incoming wikilinks. These are knowledge islands that nothing connects to.

**How to check:**
- Glob all `.md` files under `CODE_WIKI_OUTPUT_PATH`
- For each page, grep the rest of the wiki for `[[page-name]]` or markdown links to it (depending on `CODE_WIKI_LINK_FORMAT`)
- Pages with zero incoming links — **excluding `index.md` and `log.md`** — are orphans

**How to fix:**
- Identify which existing pages should link to the orphan (look for category siblings, shared `sources:`, shared tags)
- Add wikilinks in appropriate sections

### 2. Broken Wikilinks (Critical)

Find links that point to pages that don't exist.

**How to check:**
- Grep for `\[\[.*?\]\]` (and `\]\(.*?\.md\)` if `CODE_WIKI_LINK_FORMAT=markdown`) across all pages
- Extract the link targets and normalize (lowercase, strip extension, resolve relative paths)
- Check if a corresponding `.md` file exists

**How to fix:**
- If the target was renamed, update the link
- If the target should exist, create it via `code-wiki-ingest`
- If the link is wrong, remove or correct it

### 3. Missing Frontmatter (Critical)

Every page must have: `title`, `category`, `tags`, `sources`, `created`, `updated`.

**How to check:**
- Grep frontmatter blocks (scope to `^---` at file heads) instead of reading every page in full
- Flag pages missing required fields

**How to fix:**
- Add missing fields with reasonable defaults; for `sources:` escalate to a re-ingest rather than guessing

### 4. Missing Summary (Warning — soft)

Every page *should* have a `summary:` frontmatter field — 1–2 sentences, ≤200 chars. This is what cheap retrieval (e.g. `code-wiki-query`'s index-only mode) reads to avoid opening page bodies.

**How to check:**
- Grep frontmatter for `^summary:` across the wiki
- Flag pages without it, **as a soft warning, not an error** — older pages predating this field are tolerated; the check exists to nudge ingest skills into filling it on new writes.
- Also flag pages whose summary exceeds 200 chars.

**How to fix:**
- Re-ingest the page, or manually write a short summary (1–2 sentences distilled from the page's body)

### 5. Stale Content (Warning)

Pages whose recorded `updated` timestamp is older than the source code they describe.

**How to check:**
- For each page, read `sources:` from frontmatter
- For each `source_id`, check `git log -1 --format=%cI -- <source>` in the source repo
- If any source's last commit time > page `updated`, flag as stale
- If `.git-state.json` exists, additionally flag pages whose `sources:` overlap with files in `git diff --name-only <last_ingested_commit>..HEAD`

**How to fix:**
- Re-ingest the affected pages with `code-wiki-ingest`

### 6. Contradictions (Warning)

Claims that conflict across pages.

**How to check:**
- Focus on pages that share tags or `sources:`, or are heavily cross-referenced (hubs)
- Read related pages and compare claims — particularly version numbers, default values, behavioral descriptions
- Watch for "however", "in contrast", "despite" phrases that may signal existing acknowledged contradictions vs. unacknowledged ones
- Cross-check pages whose `relationships:` already declare `contradicts`

**How to fix:**
- Add an "Open Questions" section noting the contradiction
- Reference both sources and their claims
- Add `relationships: contradicts` to both pages' frontmatter

### 7. Index Consistency (Warning)

Verify `index.md` matches the actual page inventory.

**How to check:**
- Compare pages listed in `index.md` to actual `.md` files on disk
- Flag pages on disk but missing from index (and vice versa)
- Spot-check that summaries in `index.md` still match each page's current `summary:` field

**How to fix:**
- Rebuild the relevant section of `index.md` from frontmatter `title` + `summary` fields

### 8. Provenance Drift (Warning)

Check whether pages are honest about how much of their content is inferred vs extracted. See the Provenance Markers section in `code-wiki/SKILL.md`.

**How to check:**
- For each page with a `provenance:` block or any `^[inferred]`/`^[ambiguous]` markers, count sentences/bullets ending with each marker
- Compute rough fractions (`extracted`, `inferred`, `ambiguous`)
- Apply these thresholds:
  - **AMBIGUOUS > 15%**: flag as "speculation-heavy" — even 1-in-7 claims being genuinely uncertain is a signal the page needs tighter sourcing
  - **INFERRED > 40% with no `sources:` in frontmatter**: flag as "unsourced synthesis" — the page is making connections but has nothing to cite back to code
  - **Hub pages** (top 10 by incoming wikilink count) with INFERRED > 20%: flag as "high-traffic page with questionable provenance"
  - **Drift**: if the page has a `provenance:` frontmatter block, flag it when any field is more than 0.20 off from the recomputed value
- **Skip** pages with no `provenance:` frontmatter and no markers — treated as fully extracted by convention

**How to fix:**
- For ambiguous-heavy: re-ingest from source files, resolve the uncertain claims by reading code
- For unsourced synthesis: add `sources:` from the files actually referenced, or relabel as architectural inference
- For hub pages with INFERRED > 20%: prioritize for re-ingestion — errors here have the widest blast radius
- For drift: update the `provenance:` frontmatter to match the recomputed values

### 9. Confidence and Lifecycle Schema (Critical for invalid values, Warning for missing)

Enforces the confidence + lifecycle frontmatter schema (see `code-wiki/SKILL.md`, Confidence and Lifecycle section).

Two sub-modes:
- **`--check`** (default, read-only) — reports errors and warnings
- **`--fix`** — may rewrite `base_confidence` only when drift is detected (Rule 9e); never rewrites `lifecycle`

#### Rule 9a — `lifecycle` enum validation
**How to check:** Grep frontmatter for `^lifecycle:` across all pages. Flag any value not in `{draft, reviewed, verified, disputed, archived}`.
**How to fix:** n/a (only a human should set lifecycle state)

#### Rule 9b — `base_confidence` range
**How to check:** Grep frontmatter for `^base_confidence:` across all pages. Flag any value outside `[0.0, 1.0]` or any page missing the field entirely.
**How to fix:** n/a (wrong value means the ingest skill computed it wrong — surface for manual correction)

#### Rule 9c — Stale page report (computed overlay)
Staleness is never stored — it is computed at read time: `is_stale = (today − updated) > 90 days OR source_files_changed_since_last_ingest`.

**How to check:** For each page, read `updated:` from frontmatter and compute `is_stale`. If stale, also check `lifecycle:`. Report:
- Stale pages with `lifecycle: verified` with a louder annotation (these are the most dangerous — high-trust pages that may be wrong)
- All other stale pages as a standard warning
**How to fix:** `--fix` does **not** rewrite `lifecycle`. Staleness clears automatically when a re-ingest bumps `updated`.

#### Rule 9d — Supersession integrity
**How to check:** For each page with `superseded_by: "[[target]]"`:
- Verify the target page exists
- Verify the target page is not itself `archived` (no chained supersession)
- Verify there are no cycles (A supersedes B which supersedes A)
- Warn if `lifecycle != archived` while `superseded_by` is set (inconsistent state)
**How to fix:** n/a — flag for human resolution

#### Rule 9e — Confidence drift
**How to check:** For pages that have both `base_confidence:` and `sources:` in frontmatter, recompute `base_confidence` using the formula in `code-wiki/SKILL.md` (source_count_score × 0.5 + source_quality_score × 0.5). If the stored value differs from the recomputed value by more than 0.05, flag as drift.
**How to fix (`--fix` only):** Rewrite the `base_confidence` field to the recomputed value. This is the **only rule** that mutates frontmatter automatically.

### 10. Typed Relationships Validity (Warning)

Validate `relationships:` frontmatter blocks. Skip pages with no `relationships:` block — the field is optional.

**Allowed types:** `extends`, `implements`, `contradicts`, `derived_from`, `uses`, `replaces`, `related_to`

**How to check:**
- Grep frontmatter for `^relationships:` across all wiki pages
- For each page that has a `relationships:` block, read its frontmatter (not the full page body)
- For each entry in the block:
  1. **Type validation** — flag any `type:` value not in the allowed set above
  2. **Broken target** — strip `[[` and `]]` from the `target:` string, normalize (lowercase, spaces→hyphens, strip `.md`), and check whether a `.md` file at that path exists in the wiki. Flag unresolved targets.
  3. **Self-reference** — flag any entry where the resolved target equals the page's own path

**How to fix:**
- Invalid type: correct the value to the nearest allowed type, or use `related_to` when the type is ambiguous
- Broken target: update or remove the entry; if the target page should exist, create it via `code-wiki-ingest` first
- Self-reference: remove the entry

### 11. Code-Wiki Sync Check (Critical)

Compare `.git-state.json`'s `last_ingested_commit` against the source repo's current `HEAD`. If they differ, the wiki may be outdated relative to the code.

**How to check:**
- Read `last_ingested_commit` from `.git-state.json` at the wiki root
- In the source repo, run `git rev-parse HEAD` to get the current commit
- If they match: report `Wiki in sync with HEAD <sha>`
- If they differ: compute the delta
  ```
  git diff --name-only <last_ingested_commit>..HEAD
  git log --oneline <last_ingested_commit>..HEAD
  ```
- Report number of commits behind, number of files changed, and a small sample of the changed files

**How to fix:**
- Run `code-wiki-ingest` (incremental mode) to bring the wiki up to date
- If the delta is large (>50 files), suggest `code-wiki-ingest --full`
- If `.git-state.json` is missing or malformed, treat as first-time setup and direct the user to `code-wiki-ingest`

## Output Format

Report findings as a structured Markdown document, grouped by severity. Each item: file path + concise problem description + suggested fix.

```markdown
## Code Wiki Health Report — <YYYY-MM-DD>

Wiki: $CODE_WIKI_OUTPUT_PATH
Repo: <source repo path>
Wiki HEAD synced to: <commit short sha> | Repo HEAD: <commit short sha>

---

### 🔴 Critical (N found)

#### Broken Wikilinks (N)
- `03-modules/auth-service.md:42` — links to `[[03-modules/legacy-auth]]` which doesn't exist → remove or correct

#### Missing Frontmatter (N)
- `04-flows/login.md` — missing: `sources`, `updated` → re-ingest to repopulate

#### Code-Wiki Sync
- ⚠️ Wiki may be outdated — synced to `abc1234`, repo HEAD is `def5678` (12 commits, 34 files changed)
  → run `code-wiki-ingest`

#### Confidence/Lifecycle Schema (N)
- `entities/bar.md` — `lifecycle: stalestate` is not a valid enum value
- `03-modules/foo.md` — `base_confidence: 1.4` is out of range [0.0, 1.0]

---

### 🟡 Warning (N found)

#### Orphaned Pages (N)
- `06-testing/integration-strategy.md` — no incoming links → add cross-refs from `02-architecture/` or `04-flows/`

#### Stale Content (N)
- `03-modules/payment.md` — sources modified 2026-05-20, page last updated 2026-04-10 → re-ingest

#### Contradictions (N)
- `05-config/env-vars.md` claims default port is `3000` but `01-overview/tech-stack.md` claims `8080`

#### Index Issues (N)
- `04-flows/new-feature.md` exists on disk but not in `index.md`
- `03-modules/removed-module.md` listed in `index.md` but missing from disk

#### Provenance Issues (N)
- `02-architecture/scaling.md` — AMBIGUOUS 22% (re-source from code)
- `03-modules/auth-service.md` — hub page (31 incoming) with INFERRED 28%
- `03-modules/cache.md` — drift: frontmatter says inferred=0.10, recomputed=0.45

#### Typed Relationship Issues (N)
- `03-modules/foo.md` — relationships[1]: type `contradication` is not an allowed type (did you mean `contradicts`?)
- `03-modules/bar.md` — relationships[0]: target `[[03-modules/nonexistent]]` resolves to no page

---

### 🔵 Info (N found)

#### Missing Summary (N — soft)
- `07-ops/runbook.md` — no `summary:` field
- `08-decisions/adr-007.md` — summary exceeds 200 chars

#### Stale (computed overlay) (N)
- `03-modules/legacy-router.md` — STALE (last updated 180 days ago, `lifecycle: verified`) ⚠️ HIGH PRIORITY
- `06-testing/coverage-notes.md` — STALE (last updated 137 days ago, `lifecycle: draft`)

---

### Summary

| Check | Count |
|---|---|
| Orphaned pages | X |
| Broken wikilinks | Y |
| Missing frontmatter | Z |
| Missing summary (soft) | S |
| Stale content | T |
| Contradictions | C |
| Index issues | I |
| Provenance issues | P |
| Confidence/lifecycle issues | L |
| Typed relationship issues | R |
| Sync delta | <commits behind> |
| **Total** | **N** |
```

## After Linting

Append to `log.md`:

```
- [TIMESTAMP] LINT issues_found=N orphans=X broken_links=Y missing_fm=F stale=T contradictions=W index_issues=I prov_issues=P lifecycle_issues=L relationship_issues=R sync_behind=<commits>
```

Then offer: "Run `code-wiki-lint --consolidate` to apply automatic fixes (with dry-run preview), or address issues manually."

---

## Consolidate Mode (`--consolidate`)

Triggered by `code-wiki-lint --consolidate`. Switches from report-only to **act-and-report** — the periodic self-healing pass.

### Safety protocol

**Always run in dry-run first.** Before writing anything:

1. Run all 11 lint checks (Step 1–11 above).
2. Print the planned consolidation actions as a structured list (see Dry-Run Output below).
3. Ask the user: `"Apply these N changes? [yes / no / select]"`.
4. Only proceed with writes after explicit confirmation. If the user selects individual actions, apply only those.
5. Never merge or rewrite page bodies wholesale — only patch frontmatter, fix links, add cross-refs, and append callouts.

### Consolidation actions (in order, after confirmation)

#### Action 1: Fix broken wikilinks

For each broken `[[Target]]` found in Check 2:
- Search the wiki for a page whose title or filename is the closest fuzzy match (grep `index.md` titles, then filenames)
- If a unique best match exists (edit distance ≤ 2 characters or same root word): rewrite the link. Record: `[[Original]] → [[corrected-page]]`.
- If no match or ambiguous: leave the link and add an HTML comment next to it: `<!-- broken link: no match found -->`.
- Never create a new page just to satisfy a broken link — that's `code-wiki-ingest`'s job.

#### Action 2: Add missing cross-references for orphans

For each orphan page found in Check 1 (zero incoming links):
- Grep the wiki body text for mentions of the page's title or aliases (case-insensitive)
- For each plain-text mention found in another page, replace with a `[[wikilink]]`
- Limit to 3 insertions per orphan — don't flood pages with links
- Scoped to orphans only; broad cross-linking is out of scope for lint

#### Action 3: Correct lifecycle states

Apply these rules automatically (they enforce the documented state machine — no human judgement needed):
- **Promote `draft` → `reviewed`:** pages where `lifecycle: draft` AND `created` > 30 days ago AND `base_confidence > 0.7`. Set `lifecycle: reviewed`, `lifecycle_changed: <today>`, `lifecycle_reason: "auto-promoted by code-wiki-lint --consolidate: age>30d, confidence>0.7"`.
- **Stale-callout for verified pages:** for verified pages where `is_stale = (today − updated) > 180 days`, add a callout at the top of the page body:
  ```
  > ⚠️ **Stale**: This page was last updated <date>. Verify against current code before relying on it.
  ```
  Only add if the callout isn't already present. Do **not** change the `lifecycle` value — stale is computed, not stored.
- **Do not change `reviewed` → `verified` or any other transition** — those are human-only.

#### Action 4: Tier demotion

For pages with `tier: supporting` (or unset) that have **0 incoming links** AND **haven't been updated in 90+ days**:
- Set `tier: peripheral`
- Emit a list of demotions for the user to review
- Do not demote `tier: core` pages automatically — those were manually set

#### Action 5: Contradiction callouts

For each pair of pages flagged as contradicting each other (via `relationships: contradicts` in frontmatter, or flagged in Check 6):
- Check whether a `> ⚠️ Contradiction flagged with [[Other Page]]` callout already exists near the relevant claim
- If not, add it at the end of the "Key Points" section (or before "Open Questions" if no "Key Points" section). Keep it concise — one line.
- Do not resolve the contradiction; only flag it visually.

#### Action 6: Confidence drift fix

For pages flagged by Rule 9e (drift > 0.05): rewrite `base_confidence` to the recomputed value. This is the only frontmatter field auto-mutated by `--consolidate`.

#### Action 7: Update `index.md`

After all body/frontmatter writes, regenerate `index.md` from the current set of pages (using each page's `title` + `summary` frontmatter fields). This keeps Check 7 clean after consolidation.

#### Action 8: Write consolidation report

After all actions, write a report to `08-decisions/consolidation-<YYYY-MM-DD>.md` (or whichever category your wiki uses for meta records):

```markdown
---
title: Consolidation Report <YYYY-MM-DD>
category: 08-decisions
tags: [maintenance, consolidation]
sources: []
summary: Auto-generated consolidation report from code-wiki-lint --consolidate run on <date>.
lifecycle: draft
lifecycle_changed: <date>
tier: peripheral
created: <ISO timestamp>
updated: <ISO timestamp>
---

# Consolidation Report — <YYYY-MM-DD>

## Summary
- Broken links fixed: N
- Cross-references added: M
- Lifecycle states updated: K
- Tier demotions: D
- Contradiction callouts added: C
- Confidence drift corrected: F

## Broken Link Fixes
- `03-modules/foo.md:12` — `[[OldTarget]]` → `[[correct-target]]`
- `04-flows/bar.md:8` — `[[Missing]]` retained with `<!-- broken link -->` comment (no match)

## Cross-References Added (orphan rescue)
- `06-testing/integration-strategy.md` — now linked from: `[[02-architecture/overview]]`, `[[04-flows/login]]`

## Lifecycle Updates
- `03-modules/old-draft.md` — draft → reviewed (age 45d, confidence 0.74)
- `02-architecture/scaling.md` — stale callout added (last updated 2025-10-01)

## Tier Demotions
- `03-modules/unused-util.md` — supporting → peripheral (0 links, 120 days stale)

## Contradiction Callouts
- `05-config/env-vars.md` — flagged contradiction with `[[01-overview/tech-stack]]`

## Confidence Drift Fixes
- `03-modules/auth-service.md` — base_confidence: 0.80 → 0.59 (recomputed from 4 sources)
```

### Dry-Run Output (shown before any writes)

```
code-wiki-lint --consolidate — Dry Run

Planned actions (N total):
[1] Fix broken link: 03-modules/foo.md:12 [[OldTarget]] → [[correct-target]]
[2] Add cross-ref: 06-testing/integration-strategy.md ← [[02-architecture/overview]] (orphan rescue)
[3] Lifecycle: 03-modules/old-draft.md → reviewed (age 45d, confidence 0.74)
[4] Tier demotion: 03-modules/unused-util.md → peripheral (0 links, 112 days stale)
[5] Contradiction callout: 05-config/env-vars.md ↔ [[01-overview/tech-stack]]
[6] Confidence drift: 03-modules/auth-service.md 0.80 → 0.59
[7] Rebuild index.md (3 missing entries, 1 stale summary)

Apply these 7 changes? [yes / no / select by number]
```

### Log entry for consolidate mode

```
- [TIMESTAMP] LINT_CONSOLIDATE links_fixed=N orphans_rescued=M lifecycle_updates=K tier_demotions=D contradiction_callouts=C confidence_fixes=F report=08-decisions/consolidation-YYYY-MM-DD.md
```

## QMD Refresh After Wiki Writes

QMD is an optional semantic search index, not the source of truth. If `$QMD_WIKI_COLLECTION` is empty or unset, skip this step. Run it only after `--consolidate` has written or rewritten wiki markdown. If QMD refresh fails, do **not** roll back the wiki changes; report the QMD status separately.

Use `$QMD_CLI` if set; otherwise use `qmd`.

```bash
${QMD_CLI:-qmd} update
```

If the output says vectors are needed or embeddings may be stale, run:

```bash
${QMD_CLI:-qmd} embed
```

Verify the collection with either:

```bash
${QMD_CLI:-qmd} ls "$QMD_WIKI_COLLECTION"
```

or, when a specific page path is known:

```bash
${QMD_CLI:-qmd} get "qmd://$QMD_WIKI_COLLECTION/<page>.md" -l 5
```

Record one of:
- `QMD refreshed: update + embed + verified`
- `QMD refreshed: update only + verified`
- `QMD skipped: QMD_WIKI_COLLECTION unset`
- `QMD skipped: qmd CLI unavailable`
- `QMD failed: <short error summary>`

Read-only lint runs (without `--consolidate`) must **not** trigger QMD refresh.

## Execution Flow Summary

1. **Config Resolution** → load `CODE_WIKI_OUTPUT_PATH`, `CODE_WIKI_LINK_FORMAT`, optional QMD vars
2. **Locate wiki root** (`CODE_WIKI_OUTPUT_PATH`, default `./wiki`); abort if missing
3. **Resolve source repo path** (positional arg → `.git-state.json` `repo_path` → CWD)
4. **Scan all `.md` files** under wiki root; read frontmatter blocks via grep first
5. **Run all 11 checks** in order; collect findings into severity-bucketed lists
6. **Generate report** (Markdown to stdout) with summary table
7. **If `--consolidate`:**
   - Print dry-run preview
   - Wait for explicit user confirmation
   - Apply approved actions in order (1 → 7)
   - Write consolidation report page
   - Rebuild `index.md`
   - Refresh QMD if configured
8. **Append to `log.md`** (always — even on read-only runs)

## Quality Checklist

Before declaring the lint complete, self-verify:

- [ ] Config resolved successfully (or user prompted for setup)
- [ ] `index.md` and `log.md` both read once at start
- [ ] `.git-state.json` read; sync check performed even if file is missing (then reported as such)
- [ ] All 11 checks executed in order — none silently skipped
- [ ] Findings grouped by severity (Critical / Warning / Info), not lumped together
- [ ] Each finding includes: file path, concise issue, suggested fix
- [ ] Summary table at end of report with counts per check
- [ ] `log.md` entry appended with structured counters
- [ ] In `--consolidate` mode: dry-run shown **before** any write; user confirmation explicit
- [ ] In `--consolidate` mode: no page bodies rewritten wholesale (only patched/appended)
- [ ] In `--consolidate` mode: only `base_confidence` was auto-mutated in frontmatter (per Rule 9e)
- [ ] In `--consolidate` mode: `index.md` rebuilt after all writes
- [ ] QMD refresh attempted only if `--consolidate` ran writes AND `QMD_WIKI_COLLECTION` is set
- [ ] If QMD refresh failed, wiki changes were preserved and status reported separately

## Reference

For the underlying schema (page templates, frontmatter fields, lifecycle states, provenance markers, confidence formula, link formats, git state protocol), see `code-wiki/SKILL.md`. This skill enforces the schema; it does not redefine it.
