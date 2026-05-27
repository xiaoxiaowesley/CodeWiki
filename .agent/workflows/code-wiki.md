---
name: code-wiki
description: CodeWiki workflows — ingest code, lint wiki, query wiki, rebuild wiki.
commands:
  - name: code-wiki-ingest
    description: Analyze a code repository and generate structured wiki documentation.
    skill: .skills/code-wiki-ingest/SKILL.md
  - name: code-wiki-lint
    description: Audit the wiki for broken links, orphan pages, stale content, and missing frontmatter.
    skill: .skills/code-wiki-lint/SKILL.md
  - name: code-wiki-query
    description: Answer questions from the generated code wiki with [[wikilink]] citations.
    skill: .skills/code-wiki-query/SKILL.md
  - name: code-wiki-rebuild
    description: Archive the current wiki, rebuild from scratch, or restore a previous version.
    skill: .skills/code-wiki-rebuild/SKILL.md
---

# CodeWiki — Workflow Registry

Each command above maps to a `SKILL.md` in `.skills/`. When a user invokes one
of these commands, read the mapped skill file and follow its instructions
exactly. The skills handle output path resolution, manifest tracking, and
`[[wikilink]]` connectivity on their own.

For the full routing table and project context, see `AGENTS.md` at the repo root.
