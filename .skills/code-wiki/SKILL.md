---
name: code-wiki
description: >
  The foundational knowledge distillation pattern for building and maintaining an AI-powered code wiki.
  Based on Andrej Karpathy's LLM Wiki architecture, adapted for source code repositories.
  Use this skill whenever the user wants to understand the code-wiki pattern, set up a new code knowledge base,
  or needs guidance on the three-layer architecture (source code → wiki → schema).
  Also use when discussing knowledge management strategy, wiki structure decisions, or how
  to organize distilled code knowledge. This is the "theory" skill — other skills handle specific operations
  (ingesting, querying, linting).
---

# Code Wiki — Knowledge Distillation Pattern

You are maintaining a persistent, compounding knowledge base for a source code repository. The wiki is not a chatbot — it is a **compiled artifact** where code knowledge is distilled once and kept current, not re-derived on every query.

## Three-Layer Architecture

### Layer 1: Raw Sources (immutable)

The source code repository — the actual `.ts`, `.py`, `.go`, `.java`, `.rs` files, configuration, tests, and documentation that live in the codebase. These are **never modified** by the wiki system. The repo path is passed as a skill parameter (defaults to CWD).

Think of raw sources as the authoritative ground truth — correct by definition but hard to understand holistically. A 200-file codebase can answer any specific "what does this line do?" question, but cannot directly answer "how does authentication flow through the system?" without expensive multi-file reasoning.

### Layer 2: The Wiki (LLM-maintained)

A collection of interconnected markdown files organized by category, living at the path configured via `CODE_WIKI_OUTPUT_PATH` in `.env` (default: `./wiki`). This is the compiled knowledge — synthesized, cross-referenced, and navigable. Each page has:

- YAML frontmatter (title, category, tags, sources, timestamps, provenance)
- Internal links connecting related concepts (wikilink or markdown format)
- Clear provenance — every claim traces back to source files
- Git-state awareness — knows which commit it was last synced with

The wiki is a **read-optimized projection** of the codebase. It trades write-time compute (LLM analysis) for read-time speed (instant answers from pre-compiled pages).

### Layer 3: The Schema (this skill + config)

The rules governing how the wiki is structured — categories, conventions, page templates, operational workflows, and the configuration system. The schema tells the LLM *how* to maintain the wiki.

Key schema artifacts:
- This skill file (`code-wiki/SKILL.md`) — the pattern definition
- `schema/wiki-structure.yaml` — configurable wiki directory layout
- `.env` / `.env.example` — environment configuration
- `.git-state.json` — repository sync state

## Wiki Organization — Configurable Framework

The wiki structure is defined in `schema/wiki-structure.yaml`. This file controls which directories exist in the wiki output and what each category contains. The default structure ships with 8 categories optimized for code understanding:

| Category | Label | Purpose |
|---|---|---|
| `01-overview/` | 项目总览 | What this repo is — background, tech stack, entry points |
| `02-architecture/` | 架构说明 | How the code is organized — layers, components, boundaries |
| `03-modules/` | 模块说明 | What each module does — responsibilities, key files, APIs |
| `04-flows/` | 流程说明 | How features work end-to-end — call chains, data flow |
| `05-config/` | 配置说明 | What each config does — env vars, defaults, impacts |
| `06-testing/` | 测试说明 | How to test — strategy, structure, coverage |
| `07-ops/` | 排障手册 | What to do when things break — errors, debugging, fixes |
| `08-decisions/` | 决策记录 | Why things are the way they are — ADRs, tradeoffs |

### Customization

Edit `schema/wiki-structure.yaml` to add/remove/reorder categories. Each category defines:
- `name` — directory name (numeric prefix for sort order)
- `label` — human-readable name
- `description` — one-line purpose (used in prompts)
- `sections` — suggested section headings for pages in this category

Skills read this file at runtime to determine valid categories and generate appropriate pages.

## Special Files

Every wiki has these files at its root:

### `index.md`
A content-oriented catalog organized by category. Each entry has a one-line summary and tags. Rebuild this after every ingest operation.

### `log.md`
Chronological append-only record tracking every operation:

```markdown
## Log

- [2026-05-26T10:00:00Z] INGEST commit="abc1234" pages_updated=8 pages_created=3
- [2026-05-26T11:00:00Z] QUERY query="How does auth middleware work?" result_pages=4
- [2026-05-27T09:00:00Z] LINT issues_found=2 orphans=1 stale=1
```

## Page Template

When creating a new wiki page, use this structure:

```markdown
---
title: Page Title
category: 03-modules
tags: [authentication, api]
aliases: [登录模块]
relationships:
  - target: "[[02-architecture/layered-design]]"
    type: uses
sources: [src/auth/login.ts, src/auth/middleware.ts]
summary: One or two sentences, ≤200 chars, so a reader can preview this page without opening it.
provenance:
  extracted: 0.60
  inferred: 0.35
  ambiguous: 0.05
base_confidence: 0.75
lifecycle: draft
lifecycle_changed: 2026-05-26
tier: supporting
created: 2026-05-26T10:00:00Z
updated: 2026-05-26T10:00:00Z
---
```

### Category-Specific Page Templates

The page body structure varies by wiki category. Use the matching template below. Every template starts with a narrative introduction — never open a page with bullet points.

#### 01-overview/ — Project Overview

```
# {title}

{1–2 paragraphs: what the project is, what problem it solves, who it's for}

## Tech Stack
{Paragraph-form overview of technologies and why they were chosen}

## Project Structure
{Directory tree + prose explaining each major directory's role}

## Entry Points
{Key entry files and what each one bootstraps}
```

#### 02-architecture/ — Architecture & Design

```
# {title}

{1–2 paragraphs: how the system is organized, core design philosophy}

## System Overview
{Narrative explanation + Mermaid diagram of the high-level architecture}

## Layer / Component Breakdown
{Per layer or component: responsibility → interactions → design rationale}

## Data Flow
{How data moves through the system, with sequenceDiagram}

## Design Decisions
{Key architectural choices, ADR-style: context → decision → consequences}
```

#### 03-modules/ — Module Documentation

```
# {title}

{One paragraph: what this module does and its role in the system}

## Responsibilities
{Core responsibilities described in prose, not bullet lists}

## How It Works
{Narrative explanation of the key flows, with diagrams where helpful}

## Key Interfaces
{Exported public API / interfaces, with purpose of each}

## Dependencies
{What it depends on, who depends on it, and why}

## Implementation Notes
{Notable implementation details, edge cases, performance considerations}
```

#### 04-flows/ — Process & Data Flows

```
# {title}

{One paragraph: what business goal this flow achieves}

## Overview
{High-level end-to-end summary of the flow}

## Step-by-Step Walkthrough
{Narrative walkthrough of each step, with sequenceDiagram}

## Error Handling
{Exception paths and recovery strategies}

## Key Code Paths
{Source file references with inline links}
```

#### 05-config/ — Configuration & Environment

```
# {title}

{One paragraph: what this configuration controls and when you'd change it}

## Configuration Options
{Each option: name, purpose, default, allowed values — prose-first, tables for dense parameter lists}

## Resolution Order
{How config values are resolved: defaults → file → env vars → CLI flags}

## Examples
{Common configuration scenarios with explanations}
```

#### 06-testing/ — Testing Strategy

```
# {title}

{One paragraph: testing philosophy and what's covered}

## Test Architecture
{How tests are organized, what frameworks are used, and why}

## Key Test Suites
{Major test suites, what they validate, how to run them}

## Coverage & Gaps
{Current coverage status, known gaps, and testing priorities}
```

#### 07-ops/ — Operations & Troubleshooting

```
# {title}

{One paragraph: what operational concern this page addresses}

## Symptoms
{How to recognize the issue — error messages, behaviors, metrics}

## Diagnosis
{Step-by-step investigation approach}

## Resolution
{Fix procedures, with commands and expected outcomes}

## Prevention
{How to prevent recurrence — monitoring, config changes, code fixes}
```

#### 08-decisions/ — Decision Records (ADR)

```
# {title}

## Status
{Proposed / Accepted / Deprecated / Superseded by [[link]]}

## Context
{What situation or problem prompted this decision}

## Decision
{What was decided and why}

## Alternatives Considered
{What other options were evaluated and why they were rejected}

## Consequences
{Positive and negative outcomes of the decision}
```

### Mermaid Diagrams

When documenting processes, interactions, or data flows, use Mermaid diagrams to provide visual clarity. Choose the diagram type based on the content:

| Content pattern | Diagram type |
|---|---|
| Multi-step call chains, request-response interactions between components | `sequenceDiagram` |
| Decision flows, state transitions, data pipelines, lifecycle stages | `flowchart TD` |

**Syntax:**

Use fenced code blocks with the `mermaid` language identifier:

    ```mermaid
    sequenceDiagram
        participant A as ModuleA
        participant B as ModuleB
        A->>B: request
        B-->>A: response
    ```

    ```mermaid
    flowchart TD
        A[Start] --> B{Condition}
        B -->|Yes| C[Action]
        B -->|No| D[Alternative]
    ```

**Source annotation (required):**

Every diagram MUST be followed by a blockquote listing the source code locations that the diagram describes:

    > Sources:
    > - [FileName.swift:L1-L2](file://ProjectRoot/Path/To/FileName.swift#L1-L2)
    > - [AnotherFile.ts:L10-L30](file://ProjectRoot/Path/To/AnotherFile.ts#L10-L30)

## Provenance Markers

Every claim on a wiki page has one of three provenance states. Mark them inline so the reader (and future ingest passes) can tell signal from synthesis.

| State | Marker | Meaning |
|---|---|---|
| **Extracted** | *(no marker — default)* | A paraphrase of something directly observable in the source code. |
| **Inferred** | `^[inferred]` suffix | An LLM-synthesized claim — a pattern, generalization, or implication the code doesn't state directly. |
| **Ambiguous** | `^[ambiguous]` suffix | Sources disagree, code behavior is unclear, or documentation contradicts implementation. |

Example:

```markdown
- The `AuthService` validates JWT tokens on every request.
- This suggests the system prioritizes security over performance. ^[inferred]
- The token expiry is set to 24h in code but 1h in the config docs. ^[ambiguous]
```

**Why this syntax:**
- `^[...]` is footnote-adjacent — renders cleanly and never collides with `[[wikilinks]]`.
- Inline (suffix) so a single bullet stays a single bullet.
- Default = extracted means existing pages without markers stay valid.

**Frontmatter summary:** Surface the rough mix at the page level so the user can scan for speculation-heavy pages:

```yaml
provenance:
  extracted: 0.60   # rough fraction of statements with no marker
  inferred: 0.35
  ambiguous: 0.05
```

These are best-effort numbers written by the ingest skill at create/update time. `wiki-lint` recomputes them and flags drift. The block is optional — pages without it are treated as fully extracted by convention.

## Typed Relationships

Plain `[[wikilinks]]` in page bodies carry no semantic weight — they indicate "related to" but not *how*. The optional `relationships:` frontmatter block adds typed, directional edges to the knowledge graph.

### The `relationships:` block

```yaml
relationships:
  - target: "[[03-modules/auth-service]]"
    type: uses
  - target: "[[03-modules/legacy-auth]]"
    type: replaces
  - target: "[[02-architecture/layered-design]]"
    type: implements
```

Each entry has two required fields:
- `target` — a wikilink (using the same format as `CODE_WIKI_LINK_FORMAT`) to the related page
- `type` — one of the allowed semantic types below

### Allowed relationship types

| Type | Meaning | Example |
|---|---|---|
| `extends` | This page builds on or generalises the target | UserService extends BaseService |
| `implements` | This page is a concrete realisation of the target design | AuthMiddleware implements SecurityLayer |
| `contradicts` | This page's behavior conflicts with the target | Implementation contradicts Documentation |
| `derived_from` | This page is based on or adapted from the target | V2Handler derived from V1Handler |
| `uses` | This page depends on or calls into the target | OrderService uses PaymentGateway |
| `replaces` | This page supersedes or deprecates the target | NewRouter replaces LegacyRouter |
| `related_to` | Catch-all: related but no stronger directional type applies | Module A related to Module B |

### Rules

- **Optional field** — omit the block entirely if no typed relationships are known. Untagged wikilinks remain valid and are treated as `related_to`.
- **Don't duplicate** — if `[[foo]]` already appears as an inline wikilink, the `relationships:` entry just enriches it with a type; it is not a second link.
- **Direction matters** — the page declaring the entry is the *source*; `target` is the destination. Only declare relationships from this page's perspective.
- **Don't fabricate** — only add a typed entry when the source code makes the relationship direction and type clear. When in doubt, use `related_to` or omit.

## Confidence and Lifecycle

Every page carries two orthogonal trust signals.

### Required fields

```yaml
base_confidence: 0.75          # [0.0, 1.0] — time-independent quality estimate
lifecycle: draft               # draft | reviewed | verified | disputed | archived
lifecycle_changed: 2026-05-26  # ISO date of last state transition
# lifecycle_reason: "..."      # optional free-text — why the state changed
# superseded_by: "[[new-page]]" # wikilink; only when lifecycle=archived
```

### Confidence formula

```
base_confidence = source_count_score * 0.5 + source_quality_score * 0.5

source_count_score   = min(distinct_source_files / 3, 1.0)
source_quality_score = avg(quality score per distinct source file)
```

**Source-quality buckets** (use the highest-matching bucket):

| Bucket | Score | Examples |
|---|---|---|
| `source_code` | 0.9 | Implementation files — `.ts`, `.py`, `.go`, `.java`, `.rs` |
| `documentation` | 0.85 | README, docs/, API specs, JSDoc/docstrings |
| `test_file` | 0.7 | Unit tests, integration tests, e2e tests |
| `config` | 0.6 | Configuration files, environment templates, CI/CD |
| `comment` | 0.5 | Inline comments, TODO markers, code annotations |
| `llm_generated` | 0.3 | LLM-synthesized observations with no direct code backing |

**A `source_id`** for code wikis is the file path relative to repo root. This prevents counting re-exports or barrel files as distinct knowledge sources.

### Lifecycle state machine

Five states. **`stale` is not a state** — it is a computed overlay: `is_stale = (today − updated) > 90 days OR source_files_changed_since_last_ingest`.

| State | Entered by | Notes |
|---|---|---|
| `draft` | Any ingest skill on first write | Default for all new pages |
| `reviewed` | Human edit only | Human has verified accuracy |
| `verified` | Human edit only | Time alone never demotes verified pages |
| `disputed` | Manual edit only | Overrides every state except `archived` in display |
| `archived` | Manual edit, or ingest skill setting `superseded_by` | Terminal |

Only ingest skills set `draft`. All other transitions require a human editor. Update `lifecycle_changed` whenever the state changes.

## Importance Tiering

The `tier:` field controls which pages get updated on each ingest pass and their priority in retrieval.

### Three tiers

| Tier | Meaning | Ingest behavior | Query priority |
|---|---|---|---|
| `core` | Load-bearing pages — architecture, main modules, critical flows | Always update when related files change | Surfaced first |
| `supporting` *(default)* | Standard wiki pages with moderate connectivity | Update when source has clear new information | Standard priority |
| `peripheral` | Low-connectivity pages — utility helpers, minor configs | Skip unless source is primarily about this topic | Last resort |

### Assignment rules

- **New pages:** default to `tier: supporting`
- **Promote to `core`:** when a page accumulates ≥5 incoming wikilinks OR describes system-level architecture/flows
- **Demote to `peripheral`:** when a page has ≤1 incoming link and covers a single utility/helper
- **Human override always wins** — edit `tier:` manually to lock a page at any level
- Existing pages without `tier:` are treated as `supporting` (backward compatible)

## Retrieval Primitives

Reading the wiki is the dominant cost of every read-side skill. Use the cheapest primitive that can answer the question and **escalate only when the cheaper one is insufficient**.

| Need | Primitive | Relative cost |
|---|---|---|
| Does a page exist? What's its title/category/tags? | Read `index.md` or grep frontmatter `^---` blocks | **Cheapest** |
| 1–2 sentence preview of a page | Read the `summary:` field in its frontmatter | **Cheap** |
| A specific claim or section inside a page | `Grep -A <n> -B <n> "<term>" <file>` — matching lines + context | **Medium** |
| Whole-page content | `Read <file>` | **Expensive** — last resort |
| Semantic concept search across wiki + code | QMD semantic search (if configured) | **Variable** — depends on index |
| Relationships across pages | Grep `\[\[.*?\]\]` across the wiki, or walk wikilinks from a known page | Case-by-case |

**The rule:** escalate only when the cheaper primitive can't answer the question. If you can answer from `summary:` fields alone, don't read page bodies. A 500-line page opened to read 15 lines is 485 lines of wasted tokens.

**Why this matters:** a 20-page wiki lets you get away with full scans. A 200-page wiki does not. The primitives above are how the skills framework scales to large wikis without a database.

## Git State Tracking

The wiki tracks its synchronization state with the source repository via `.git-state.json` at the wiki output root.

### `.git-state.json` format

```json
{
  "last_ingested_commit": "abc1234def5678",
  "last_ingested_at": "2026-05-26T10:00:00Z",
  "branch": "main",
  "repo_path": "/path/to/source/repo",
  "history": [
    {
      "commit": "abc1234def5678",
      "ingested_at": "2026-05-26T10:00:00Z",
      "pages_created": 3,
      "pages_updated": 8,
      "pages_deleted": 0
    },
    {
      "commit": "prev1234commit",
      "ingested_at": "2026-05-25T14:00:00Z",
      "pages_created": 12,
      "pages_updated": 0,
      "pages_deleted": 0
    }
  ]
}
```

### Protocol

1. **Before ingest:** Read `.git-state.json` to determine `last_ingested_commit`. Compute the diff (`git diff --name-only <last_commit>..HEAD`) to identify changed files.
2. **During ingest:** Process only changed files (unless `--full` flag forces full re-ingest).
3. **After ingest:** Update `.git-state.json` with the new HEAD commit, timestamp, and page counts.
4. **Missing state file:** If `.git-state.json` doesn't exist, treat as first-time ingest — process all files, then create the state file.

### Delta computation

```
changed_files = git diff --name-only <last_ingested_commit>..HEAD
new_files     = files in changed_files not previously ingested
modified_files = files in changed_files previously ingested
deleted_files  = files removed since last commit
```

Each skill that writes wiki pages must check and update `.git-state.json`. This enables:
- **Incremental ingest** — only process what changed
- **Staleness detection** — wiki page references deleted/moved files
- **Audit trail** — which commit produced which wiki state

## Link Format

All internal links connecting wiki pages are controlled by `CODE_WIKI_LINK_FORMAT` from the resolved config (default: `wikilink`).

| Setting | Syntax | Example |
|---|---|---|
| `wikilink` *(default)* | `[[path/to/page]]` or `[[path/to/page\|display text]]` | `[[03-modules/auth-service\|Auth Service]]` |
| `markdown` | `[display text](relative/path.md)` | `[Auth Service](../03-modules/auth-service.md)` |

### Generating markdown-format links

When `CODE_WIKI_LINK_FORMAT=markdown`:
1. Compute the path from the **current file's directory** to the **target `.md` file** using `..` to climb up.
2. Use the page title or a natural phrase as display text.
3. Always include the `.md` extension.

| Current file | Target | Relative link |
|---|---|---|
| `index.md` | `03-modules/auth-service.md` | `[Auth Service](03-modules/auth-service.md)` |
| `03-modules/auth-service.md` | `04-flows/login-flow.md` | `[Login Flow](../04-flows/login-flow.md)` |
| `01-overview/tech-stack.md` | `03-modules/auth-service.md` | `[Auth Service](../03-modules/auth-service.md)` |

**Scope:** this setting affects only newly written or updated links. Existing wiki content is never automatically migrated.

Every write skill reads `CODE_WIKI_LINK_FORMAT` from config before generating links and applies the correct format.

## Config Resolution Protocol

**All skills must resolve config using this algorithm — do not hard-code paths directly.** This ensures project-local and global setups both work correctly.

### Resolution order

1. **Walk up from CWD** — look for a `.env` file in the current directory, then each parent, up to `$HOME`. Stop at the first `.env` that contains `CODE_WIKI_OUTPUT_PATH`.
2. **Global config** — if no local `.env` found, read `~/.code-wiki/config`.
3. **Prompt setup** — if neither exists, tell the user: "No config found. Run the setup skill to initialize your code wiki."

```
find_config() {
  dir="$PWD"
  while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
    [[ -f "$dir/.env" ]] && grep -q "CODE_WIKI_OUTPUT_PATH" "$dir/.env" && { echo "$dir/.env"; return; }
    dir="$(dirname "$dir")"
  done
  [[ -f "$HOME/.code-wiki/config" ]] && { echo "$HOME/.code-wiki/config"; return; }
  echo ""
}
```

### Standard "Before You Start" block

Every skill's setup section should read:

> **Resolve config** — follow the Config Resolution Protocol in `code-wiki/SKILL.md`. Walk up from CWD for `.env`, fall back to `~/.code-wiki/config`, else prompt setup. This gives `CODE_WIKI_OUTPUT_PATH` and any tool-specific overrides.

## QMD Semantic Search Integration

QMD is an optional semantic search index layered on top of the wiki and source code. The markdown wiki is the source of truth — QMD provides accelerated concept-level retrieval.

### Two collections

| Collection | Env var | Indexes |
|---|---|---|
| Wiki collection | `QMD_WIKI_COLLECTION` | Compiled wiki pages |
| Code collection | `QMD_CODE_COLLECTION` | Source code files |

### Behavior

- **Without QMD:** All skills fall back to Grep/Glob — fully functional, just slower.
- **With QMD:** Semantic search enables concept-level matches across wiki and code (e.g., "authentication logic" finds relevant files even without the word "auth").

### Freshness protocol

Any skill that writes wiki markdown should refresh QMD after the vault write completes, but only when `QMD_WIKI_COLLECTION` is configured and QMD transport is available. If QMD refresh fails, keep the wiki changes and report the QMD status separately. Read-only skills should not refresh QMD.

## Core Principles

1. **Compile, don't retrieve.** The wiki is pre-compiled knowledge. When you ingest source code, update every relevant page — don't just create a summary of one file.

2. **Compound over time.** Each ingest should make the wiki smarter, not just bigger. Merge new information into existing pages, resolve contradictions, strengthen cross-references.

3. **Provenance matters.** Every claim should trace to a source file. When updating a page, note which files prompted the update via the `sources:` frontmatter field.

4. **Mark inferences.** Default statements are extracted. Mark synthesized claims with `^[inferred]` and contested claims with `^[ambiguous]`. A wiki that hides its guessing rots silently; one that marks it stays trustworthy.

5. **Human curates, LLM maintains.** The human decides what repos to analyze and what questions to ask. The LLM handles the bookkeeping — updating cross-references, maintaining consistency, noting contradictions.

6. **Code is truth.** When documentation contradicts implementation, the implementation wins. Mark the contradiction with `^[ambiguous]` and note it in Open Questions.

7. **Incremental by default.** Use git state to process only what changed. Full re-ingest is expensive and should be explicit.

## Writing Philosophy

These principles govern how wiki page **content** is written. While Core Principles above cover knowledge-management mechanics (provenance, incremental updates, consistency), Writing Philosophy covers **readability and narrative quality** — making sure the wiki reads like a technical article, not a code dump.

1. **Narrate, don't enumerate.** Open every page with 1–2 paragraphs of flowing prose that explain what the subject is, why it exists, and what role it plays in the system. Use bullet lists only for parallel items (parameter tables, endpoint lists); all explanatory content should be written as connected paragraphs.

2. **Macro to micro.** Structure each page as a narrative arc: panoramic overview → core concepts → implementation details → caveats. A reader who stops after the first two sections should still understand 80 % of the subject.

3. **Explain the "why", not just the "what".** Don't just state that `AuthService` calls `TokenValidator`. Explain *why* — "AuthService validates JWTs on every request because the system uses stateless authentication to avoid session-storage scaling issues." Every non-trivial design choice deserves a sentence of rationale.

4. **Code supports prose, not the other way around.** Source-code references are evidence, not the body text. Use `[File:L1-L2](file://path#L1-L2)` links as inline citations. Never paste large code blocks — describe what the code does in natural language, then link to the source for readers who want to verify.

5. **One diagram, one story.** A diagram serves the narrative — introduce what you're about to show in prose, then present the diagram, then (if needed) annotate the key takeaways. Never drop a diagram as a substitute for a written explanation.

## Modes of Operation

The wiki supports three ingest modes:

| Mode | When to use | What happens |
|---|---|---|
| **Incremental** | Default — small delta since last ingest | Compute diff via `.git-state.json`, ingest only changed files |
| **Full** | Major refactor, first-time setup, or drift detected | Process all files in scope, update all pages |
| **Targeted** | User wants to focus on specific modules | Process only specified directories/files |

## Reference

For details on specific operations, see the companion skills:
- **code-ingest** — Analyze source code and distill into wiki pages
- **code-query** — Answer questions against the wiki
- **wiki-lint** — Audit and maintain wiki health
- **wiki-setup** — Initialize a new code wiki
- **wiki-status** — Check sync state, compute delta, recommend actions
