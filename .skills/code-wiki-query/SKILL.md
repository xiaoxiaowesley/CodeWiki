---
name: code-wiki-query
description: >
  Answer questions by searching the compiled code wiki. Uses tiered retrieval
  (index pass → QMD semantic pass → section pass → full read) to efficiently find
  and synthesize answers with citations and trust annotations. Use this skill when
  the user asks a question about a code repository's wiki, wants to find information
  across the compiled wiki, asks "what does X do", "how does Y work", "where is Z
  implemented", or wants synthesized answers with citations from wiki pages. Works
  from any project directory; the target wiki is resolved from CODE_WIKI_OUTPUT_PATH.
  Includes an index-only fast mode triggered by "quick answer", "just scan",
  "fast lookup" — returns answers from page summaries and frontmatter without
  reading page bodies.
---

# Code Wiki Query — Knowledge Retrieval

You are answering questions against a compiled code wiki, not raw source files. The wiki contains pre-synthesized, cross-referenced understanding of the codebase — architecture, modules, flows, decisions. Reach for source code only when the wiki is silent.

## Before You Start

1. **Resolve config** — follow the Config Resolution Protocol in `code-wiki/SKILL.md` (walk up CWD for `.env` → `~/.code-wiki/config` → prompt setup). This yields `CODE_WIKI_OUTPUT_PATH` and any optional QMD variables.
2. **Optional repo argument.** If the user names a specific repo or wiki path, use it to locate the right `CODE_WIKI_OUTPUT_PATH`. Otherwise use the resolved default.
3. **Load QMD settings from the resolved config** before deciding retrieval strategy. If `QMD_WIKI_COLLECTION` is set, treat QMD as available subject to transport/tool checks below. If empty or unset, mention briefly why QMD is being skipped before falling back to grep.
4. **Read `$CODE_WIKI_OUTPUT_PATH/index.md`** to understand the wiki's scope, categories, and page list. This is your map.

## Retrieval Protocol

**Follow the Retrieval Primitives table in `code-wiki/SKILL.md`.** Reading is the dominant cost of this skill — use the cheapest primitive that answers the question and escalate only when it can't. Never jump straight to full-page reads.

### Step 1: Understand the Question

Classify the query type:

- **Conceptual** — "What is X?" / "What does this repo do?" → overview pages, module summaries
- **Implementation detail** — "How is X implemented?" / "Where does Y happen?" → module pages, source links
- **Architecture** — "How is the system organized?" / "How do A and B connect?" → `02-architecture/`, relationship edges
- **Configuration** — "What does config X do?" / "How do I set Y?" → `05-config/`
- **Flow / behavior** — "How does feature X work end-to-end?" → `04-flows/`, call chains
- **Decision / rationale** — "Why was X chosen?" / "What's the tradeoff for Y?" → `08-decisions/`
- **Relationship query** — "How does X relate to Y?" / "What contradicts X?" → both pages plus their `relationships:` frontmatter
- **Gap query** — "What don't we know about X?" → check Open Questions sections

Also decide the **mode**:

- **Index-only mode** — triggered by "quick answer", "just scan", "don't read the pages", "fast lookup". Stops at Step 3. Answers from frontmatter + `index.md` only.
- **Normal mode** — the full tiered pipeline below.

### Step 2: Index Pass (cheap)

Build a candidate set *without opening any page bodies*:

- You already read `index.md` above — use it as the first filter. It lists every page with a one-line description and tags grouped by category (`01-overview/` … `08-decisions/`).
- Use `Grep` to scan page **frontmatter only** for title, tag, alias, and summary matches. A pattern like `^(title|tags|aliases|summary):` scoped to wiki `.md` files is far cheaper than content grep.
- Collect the top 5–10 candidate page paths ranked by:
  1. Exact title or alias match
  2. Tag match
  3. Summary field contains the query term
  4. `index.md` entry contains the query term
  5. Category match implied by query type (e.g. config questions → prefer `05-config/`)
- **Apply tier ordering within each rank bucket:** when two candidates score equally, prefer `tier: core` over `tier: supporting` over `tier: peripheral`. Read the `tier:` frontmatter field with the same cheap grep. Pages without a `tier:` field are treated as `supporting`.

If you're in **index-only mode**, stop here. Answer from `summary:` fields, titles, and `index.md` descriptions only. Label the answer clearly: **"(index-only answer — page bodies not read; facts below are from page summaries and may miss nuance)"**. Then skip to Step 5.

### Step 2b: QMD Semantic Pass (optional — requires `QMD_WIKI_COLLECTION` in resolved config)

**GUARD: If `$QMD_WIKI_COLLECTION` is empty or unset after config resolution, skip this entire step and proceed to Step 3. Mention the missing variable in your working update.**

> **No QMD?** Skip to Step 3 and use `Grep` directly on the wiki. QMD is faster and concept-aware but the grep path is fully functional. See `.env.example` for setup.

If `QMD_WIKI_COLLECTION` is set, run QMD before reaching for body-level `Grep` unless the question is already fully answered by `index.md` and frontmatter metadata. QMD shines when the question is semantic, asks for related context, or uses terms that may not appear verbatim in titles/frontmatter (e.g. asking about "authentication" when pages say "session middleware").

Choose the QMD transport from `$QMD_TRANSPORT`:

- `mcp` (default): use the QMD MCP tool configured in the agent.
- `cli`: run the local qmd CLI. Use `$QMD_CLI` if set; otherwise use `qmd`.

If the selected transport is unavailable (no MCP tool, `qmd` not on PATH, or the command errors), skip QMD and continue with Step 3.

For MCP transport:

```
mcp__qmd__query:
  collection: <QMD_WIKI_COLLECTION>     # e.g. "my-repo-code-wiki"
  intent: <the user's question>
  searches:
    - type: lex    # keyword match — good for exact symbol names, file paths, error messages
      query: <key terms>
    - type: vec    # semantic match — good for concepts, patterns, "how does X work"
      query: <question rephrased as a description>
```

For CLI transport, pick the command from `$QMD_CLI_SEARCH_MODE`:

Keep operator-like or punctuation-heavy tokens such as exact symbol names, file paths, `--flag-style` strings in the `lex:` line. Rewrite the `vec:` line as plain natural language without hyphenated `-term` words; QMD treats `-term` as negation.

- `quality` (default): best relevance; slower on CPU.
  ```bash
  ${QMD_CLI:-qmd} query $'lex: <key terms>\nvec: <question rephrased as a description>' -c "$QMD_WIKI_COLLECTION" -n 8 --files
  ```
- `balanced`: hybrid search without LLM reranking; use when `quality` is too slow.
  ```bash
  ${QMD_CLI:-qmd} query $'lex: <key terms>\nvec: <question rephrased as a description>' -c "$QMD_WIKI_COLLECTION" -n 8 --no-rerank --files
  ```
- `fast`: semantic-only recall, or `search` instead when exact symbols, file paths, or error messages matter.
  ```bash
  ${QMD_CLI:-qmd} vsearch "<question rephrased as a description>" -c "$QMD_WIKI_COLLECTION" -n 8 --files
  ```

The returned snippets or ranked files act as pre-read section summaries. If they answer the question fully, skip Step 3 and go straight to Step 4 (reading only the pages QMD ranked highest). Otherwise, use the ranked file list to guide which files to grep or read in Step 3.

**Also search the code collection if needed:** if `QMD_CODE_COLLECTION` is set and the wiki doesn't cover the topic, run a parallel search against the source-code collection. Cite source files separately from compiled wiki pages.

### Step 3: Section Pass (medium cost — only if Steps 2/2b are inconclusive)

For each top candidate, pull the relevant section *without reading the whole page*:

- Use `Grep -A 10 -B 2 "<query-term>" <candidate-file>` to get just the lines around the match.
- This usually returns 15–30 lines per hit instead of 100–500.
- If the section grep gives a clear answer, go straight to Step 5.

### Step 4: Full Read (expensive — last resort)

Only when Steps 2 and 3 don't answer the question:

- `Read` the top **3** candidates in full. When choosing which 3, apply tier ordering: read `core` pages before `supporting`, and skip `peripheral` pages unless they are the only match.
- Follow at most one hop of `[[wikilinks]]` from those pages if the answer requires cross-references.
- **For relationship queries** ("How does X relate to Y?" / "What contradicts X?"): also read the `relationships:` frontmatter block of the candidate pages. Each entry gives a typed, directional edge (`extends`, `implements`, `contradicts`, `derived_from`, `uses`, `replaces`, `related_to`). Surface these explicitly — "Page A *contradicts* Page B (typed edge)" is more useful than "Page A links to Page B".
- Check "Open Questions" sections for known gaps.
- If still short, **then** fall back to reading source files referenced in the page's `sources:` frontmatter. Tell the user you escalated past the wiki — this is the expensive path and they should know.

### Step 5: Synthesize the Answer

Compose your answer from wiki content:

- Cite specific wiki pages using `[[page-name]]` notation (or markdown links if `CODE_WIKI_LINK_FORMAT=markdown`).
- Note which step the answer came from ("found in summary" vs "grepped section" vs "full page read") — helps the user calibrate trust.
- If the wiki has contradictions, present both sides and surface the `^[ambiguous]` markers.
- If the wiki doesn't cover something, say so explicitly. Suggest which source files might fill the gap (use the `sources:` frontmatter of nearby pages).

**Confidence and trust annotations:** for every page cited in your answer, check its frontmatter and compute `is_stale = (today − updated) > 90 days`. Annotate risky pages inline so the user knows which citations to verify:

| Condition | Annotation |
|---|---|
| `lifecycle: archived` | `(ARCHIVED: superseded by [[target]])` — use the successor instead |
| `lifecycle: disputed` | `(DISPUTED, marked <lifecycle_changed>: <lifecycle_reason or "reason unspecified">)` |
| `is_stale` + `lifecycle: verified` | `(VERIFIED but stale: last updated <updated>)` — reader should re-verify |
| `is_stale` (other lifecycle) | `(stale: last updated <updated>)` |
| `base_confidence < 0.5` | `(low confidence: <base_confidence>)` |
| Provenance heavy on `inferred`/`ambiguous` | `(speculative: <inferred%>+<ambiguous%>)` |

Examples in a synthesized answer:

```
[[03-modules/auth-service]] (stale: last updated 2026-01-15) — Validates JWT on every request.
[[02-architecture/layered-design]] (VERIFIED but stale: last updated 2025-09-10) — Reader should reverify before relying.
[[08-decisions/token-expiry]] (DISPUTED, marked 2026-04-30: contradicted by config docs) — Earlier said 24h, now uncertain.
[[03-modules/legacy-auth]] (ARCHIVED: superseded by [[03-modules/auth-service]]) — Use the successor.
```

Pages with no `lifecycle` field (legacy pages predating the schema) are treated the same as `draft` — annotate if stale, skip otherwise. Never fabricate a `lifecycle_reason`; if the field is absent, omit the reason.

### Step 6: Log the Query

Append to `$CODE_WIKI_OUTPUT_PATH/log.md`:

```
- [TIMESTAMP] QUERY query="the user's question" result_pages=N mode=normal|index_only escalated=true|false
```

## Answer Format

Structure answers like this:

> **Based on the wiki:**
>
> [Your synthesized answer with [[wikilinks]] to source pages and inline trust annotations.]
>
> **Pages consulted:** [[page-a]], [[page-b]], [[page-c]]
>
> **Confidence:** high | medium | low — based on `base_confidence` of cited pages and how many primitives you had to escalate through.
>
> **Gaps:** [What the wiki doesn't cover that might be relevant. Point at source files or modules that could fill the gap.]
