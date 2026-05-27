# CodeWiki — Agent Context

An **AI-powered code knowledge base generator**. A skill-based framework that analyzes code repositories and produces structured wiki documentation. No scripts or heavy dependencies — everything is markdown instructions that you execute directly.

## Configuration

Resolve config using the Config Resolution Protocol:

1. **Walk up from CWD** — look for a `.env` file in the current directory, then each parent, up to `$HOME`. Stop at the first `.env` that contains `CODE_WIKI_OUTPUT_PATH`.
2. **Global config** — if no local `.env` is found, read `~/.code-wiki/config`.
3. **Prompt setup** — if neither exists, tell the user to run `code-wiki-ingest` on a repository first.

The resolved config sets `CODE_WIKI_OUTPUT_PATH` (where the generated wiki lives). It may also set `CODE_WIKI_REPO` (where this repo is cloned) and other optional variables such as `CODE_WIKI_LANG` (output language) and `CODE_WIKI_DEPTH` (analysis depth).

## Wiki Output Structure

```
$CODE_WIKI_OUTPUT_PATH/
├── index.md                # Master index — every page listed, always kept current
├── log.md                  # Chronological activity log (ingests, lints, rebuilds)
├── .manifest.json          # Tracks every ingested repo: path, timestamps, pages produced
├── architecture/           # System design, module relationships, data flow
├── modules/                # Per-module documentation (one page per logical module)
├── apis/                   # API surface documentation (endpoints, interfaces, exports)
├── patterns/               # Design patterns, idioms, conventions found in the code
├── config/                 # Build config, environment setup, dependency notes
└── guides/                 # How-to guides synthesized from code (setup, contribution, deploy)
```

Every wiki page has required frontmatter: `title`, `category`, `tags`, `sources`, `created`, `updated`. Pages connect via `[[wikilinks]]` by default, or standard Markdown links when `CODE_WIKI_LINK_FORMAT=markdown` is set in config.

## Available Skills

Skills live in `.skills/<name>/SKILL.md`. Match the user's intent to the right skill:

| User says something like… | Skill | Slash Command |
|---|---|---|
| "analyze this repo" / "generate wiki" / "ingest this codebase" | `code-wiki-ingest` | `/code-wiki-ingest` |
| "audit" / "lint" / "check wiki health" / "find broken links" | `code-wiki-lint` | `/code-wiki-lint` |
| "what does X do" / "how does Y work" / "find info on Z" | `code-wiki-query` | `/code-wiki-query` |
| "rebuild" / "archive" / "start over" / "restore" | `code-wiki-rebuild` | `/code-wiki-rebuild` |

### Skill Descriptions

- **`code-wiki-ingest`** — Analyzes source code and generates structured wiki pages. Scans repo structure, parses modules, extracts architecture, APIs, patterns, and produces interconnected documentation.
- **`code-wiki-lint`** — Audits wiki health. Finds broken links, orphan pages, stale content, missing frontmatter, and suggests improvements.
- **`code-wiki-query`** — Answers questions from the generated wiki. Searches titles, tags, and page bodies, returns synthesized answers with `[[wikilink]]` citations.
- **`code-wiki-rebuild`** — Archives the current wiki, rebuilds from scratch, or restores a previous version. Handles version management of generated documentation.

## Cross-Project Usage

The main use case: you're working in a code repository and want to generate or query its wiki documentation.

### code-wiki-ingest (generate wiki from code)

1. Resolve config to get `CODE_WIKI_OUTPUT_PATH`
2. Scan the target repository: source tree, README, package metadata, git history
3. Analyze architecture: module boundaries, dependency graph, entry points
4. Generate wiki pages: one per module, plus architecture overview, API docs, pattern docs
5. Update `.manifest.json`, `index.md`, and `log.md`

On repeat runs, checks `last_commit_synced` in `.manifest.json` and only processes the delta.

### code-wiki-query (read from wiki)

1. Resolve config to get `CODE_WIKI_OUTPUT_PATH`
2. Scan titles, tags, and `summary:` frontmatter fields first (cheap pass)
3. Only open page bodies when the index pass can't answer
4. Return a synthesized answer with `[[wikilink]]` citations

## Core Principles

- **Analyze, don't just list.** The wiki is distilled understanding of the code — architecture decisions, patterns, relationships — not raw code dumps.
- **Track everything.** Update `.manifest.json` after ingesting, `index.md` and `log.md` after any operation.
- **Connect with `[[wikilinks]]`.** Every page should link to related pages. This is what makes it a knowledge graph, not a folder of files.
- **Frontmatter is required.** Every wiki page needs: `title`, `category`, `tags`, `sources`, `created`, `updated`.
- **Delta-based updates.** On re-ingest, only process what changed since the last sync — don't regenerate everything.

## Architecture Reference

For the full pattern (page templates, output conventions), read `.skills/code-wiki-ingest/SKILL.md`.
