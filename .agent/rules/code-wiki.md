---
alwaysApply: true
description: CodeWiki skill-based framework — routing, conventions, and core rules for code knowledge base generation.
---

# CodeWiki — Agent Context

This project is an **AI-powered code knowledge base generator** — a skill-based framework that analyzes code repositories and produces structured wiki documentation.

## Quick Orientation

1. Read `~/.code-wiki/config` (or `.env` in this repo) for `CODE_WIKI_OUTPUT_PATH` — this is where the generated wiki lives.
2. Read `.manifest.json` at the wiki output root to see what's already been ingested.
3. Skills are in `.skills/` (also at `.agents/skills/`). Each subfolder has a `SKILL.md`.

## When to Use Skills

| User says something like… | Read this skill |
|---|---|
| "analyze this repo" / "generate wiki" / "ingest this codebase" | `code-wiki-ingest` |
| "audit" / "lint" / "check wiki health" / "find broken links" | `code-wiki-lint` |
| "what does X do" / "how does Y work" / any question | `code-wiki-query` |
| "rebuild" / "archive" / "start over" / "restore" | `code-wiki-rebuild` |

## Core Rules

- **Analyze, don't just list** — the wiki is distilled understanding, not raw code dumps.
- **Track everything** — update `.manifest.json`, `index.md`, and `log.md` after every operation.
- **Connect with `[[wikilinks]]`** — every page should link to related pages.
- **Frontmatter required** — every page needs `title`, `category`, `tags`, `sources`, `created`, `updated`.

For full context, read `AGENTS.md` at the repo root.
