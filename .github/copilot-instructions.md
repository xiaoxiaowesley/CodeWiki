# CodeWiki — Copilot Context

This project is an **AI-powered code knowledge base generator** — a skill-based framework that analyzes code repositories and produces structured wiki documentation using AI coding agents. There are no heavy dependencies — everything is markdown instructions that the agent executes directly.

## Project Overview

- **Purpose:** Analyze code repositories and generate structured, interconnected wiki documentation.
- **Tech Stack:** Markdown-based skills. The AI agent IS the runtime.
- **Key Config:** `.env` contains `CODE_WIKI_OUTPUT_PATH` pointing to the wiki output location. Global config at `~/.code-wiki/config`.
- **Skills:** `.skills/` contains skill folders, each with a `SKILL.md` defining a workflow.

## Key Concepts

- The wiki is a **compiled artifact** — knowledge distilled from source code into interconnected documentation pages.
- Every wiki page has YAML frontmatter: `title`, `category`, `tags`, `sources`, `created`, `updated`.
- Pages are connected with `[[wikilinks]]`.
- A `.manifest.json` in the wiki output root tracks all ingested repositories for delta-based updates.
- `index.md` and `log.md` must be updated after every operation.

## Skills Reference

| Skill | Folder | Purpose |
|---|---|---|
| Ingest | `.skills/code-wiki-ingest/` | Analyze code and generate wiki pages |
| Lint | `.skills/code-wiki-lint/` | Audit wiki health — broken links, orphans, stale content |
| Query | `.skills/code-wiki-query/` | Answer questions from the generated wiki |
| Rebuild | `.skills/code-wiki-rebuild/` | Archive, rebuild, or restore the wiki |

## Usage

Describe your intent in chat and the appropriate CodeWiki skill will be invoked:

- "Analyze this repository" → `code-wiki-ingest`
- "Check the wiki for issues" → `code-wiki-lint`
- "How does the auth module work?" → `code-wiki-query`
- "Rebuild the wiki from scratch" → `code-wiki-rebuild`

## Conventions

- When creating wiki pages, always use YAML frontmatter.
- Use `[[wikilinks]]` syntax for cross-references.
- Architecture and module docs go in their respective directories (`architecture/`, `modules/`).
- Never overwrite `.manifest.json` — update it incrementally.
