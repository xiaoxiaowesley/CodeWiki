# Code Ingest Prompt Templates

These are the mental frameworks to use when distilling source code into wiki pages.

## Code Analysis Extraction Frame

When reading a source file or module, ask these questions:

1. What is this module's **single responsibility** — what problem does it solve?
2. What are the **key design decisions** — why was it built this way instead of alternatives?
3. What are the **public interfaces** — what does it expose to the rest of the system?
4. What are the **critical dependencies** — what does it rely on, and what relies on it?
5. How does data **flow through** this module — what comes in, what goes out, what transforms happen?

## Architecture Synthesis Frame

When the analysis spans multiple modules or files:

- **Don't describe files — describe systems.** Group related files into a coherent narrative about how a subsystem works.
- **Surface implicit architecture.** Code often embodies architectural patterns (layering, event-driven, pipeline) without documenting them — make these explicit.
- **Trace decision chains.** When you see a pattern repeated across modules, explain the design philosophy once in an architecture page, then reference it from module pages.
- **Note tensions.** When two modules handle similar concerns differently, flag it — this is valuable architectural insight, not a bug.

## Flow Extraction Frame

When documenting a process or data flow:

1. What **triggers** this flow — user action, scheduled task, external event?
2. What are the **happy-path steps** from start to completion?
3. Where can the flow **fail**, and how is each failure handled?
4. What **state changes** occur — database writes, cache updates, file modifications?
5. Which **components participate**, and what does each one contribute?

## Cross-Reference Discovery

When connecting wiki pages, look for these relationship patterns:

| Pattern | Signal in code | Example |
|---------|---------------|---------|
| **uses** | Import/require statements, function calls | AuthMiddleware → TokenValidator |
| **implements** | Interface/protocol conformance, abstract class extension | UserRepo implements Repository |
| **extends** | Inheritance, decorator/wrapper patterns | AdminUser extends BaseUser |
| **triggers** | Event emission, callback registration, notification posting | OrderService triggers PaymentFlow |
| **configures** | Config file references, env var reads, default value definitions | AppConfig configures DatabasePool |
| **replaces** | Deprecation markers, migration comments, version-gated code | NewAuthService replaces LegacyAuth |

## Narrative Quality Checklist

Before finalizing a wiki page, verify:

- [ ] Opens with a narrative paragraph (not bullet points)
- [ ] Explains "why" for every non-trivial "what"
- [ ] Uses prose for explanations, lists only for parallel items
- [ ] Includes Mermaid diagrams for multi-step flows
- [ ] All diagrams have source annotations
- [ ] Source code references use `[File:L1-L2](file://path#L1-L2)` format
- [ ] First two sections give 80% understanding without reading further
