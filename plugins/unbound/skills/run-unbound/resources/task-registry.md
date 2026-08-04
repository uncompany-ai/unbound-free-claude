---
name: task-registry
description: The canonical, declarative registry of every task type Unbound recognizes — each type's execution mode (execute | define-only), its handler skill (execute only), its invocation policy (per-task | once-per-run, execute only), and its expected proposed_action. Part A is the closed type set run-unbound's task-execution loop dispatches on and the type set work-account derives its enum from; Part B is the self-contained Handler Contract every execute handler honors. This artifact declares whether a type executes, never how it is gated — the approval gate stays owned once by run-unbound's loop. Natural-language Markdown, no code (ADR-1); no external writes (ADR-4).
tier: all
---
# task-registry

The single source of truth for Unbound's **task-type vocabulary**. Before this artifact the type set
lived in two places that could drift — the prose table in `run-unbound` Step 4 and the `type` enum in
`work-account`'s canonical schema. This file collapses that into **one canonical, scannable place**.

It has two parts in one file (FR20 — a contributor reads one document):

- **Part A — Registry table:** the closed, canonical set of task types, each row declaring `mode`,
  `handler`, `invocation`, and expected `proposed_action`, followed by the **registry rules** that
  govern reading the table.
- **Part B — Handler Contract:** the self-contained "skill-like structure" every `execute` handler
  honors — what it receives, may write, may assume, and how it behaves per its `invocation` policy.

This artifact is **declarative**: it declares *whether* a type executes, never *how* a type is gated.
The approval gate is owned once by `run-unbound`'s loop (ADR-12 / D6); nothing here moves or
re-implements it. Consistent with ADR-1 the registry is natural-language Markdown (no code), and per
ADR-4 nothing here introduces an external write.

> **Consumed by (point, don't copy).** `run-unbound` Step 4 reads this table at dispatch time and
> resolves exactly two outcomes per accepted task (`execute` the named handler / `define-only`
> not walked — recapped as a rep-owned action item). `work-account` derives its `type` enum from this table and emits only
> types in it — no independent list. `run-unbound` Step 4 dispatches per this registry by pointer
> and embeds no copy — this registry is the sole statement of the type set (see "Distribution and
> current consumers").

---

## Part A — Registry table (canonical type set)

**Columns.** `type` (the dispatch key) · description · `mode` (`execute` | `define-only`) · handler
(skill name; `execute` rows only) · `invocation` (`per-task` | `once-per-run`; `execute` rows only)
· expected `proposed_action` (the intent signal the handler's trigger contract checks).

The MVP set re-homes today's `run-unbound` Step 4 prose table **verbatim** — only `followup_email`
executes (and because it folds N asks into one email, its invocation is `once-per-run`); every other
type is `define-only` with handler and invocation blank.

| `type` | Description | `mode` | Handler | `invocation` | Expected `proposed_action` |
| --- | --- | --- | --- | --- | --- |
| `followup_email` | the follow-up email to send | `execute` | `draft-followup` | `once-per-run` | `draft_email` |
| `answer_questions` | ALL outstanding questions to answer for the audience, grouped as one task | `define-only` | — | — | `draft_answers` |
| `create_deck` | a deck to create | `define-only` | — | — | `ideate_content` |
| `create_one_pager` | a one-pager to create | `define-only` | — | — | `ideate_content` |
| `create_proposal` | a formal proposal to assemble — scope, packaging, pricing | `define-only` | — | — | `draft_proposal` |
| `prepare_demo` | tailored demo / pilot prep — environment, data, success criteria | `define-only` | — | — | `prep_demo` |
| `internal` | internal / rep-owned work | `define-only` | — | — | `none` |

> **The "next meeting to schedule" is not a task type** (unchanged). That need lives in
> `work-account`'s `next_step` (plus an optional `next_call` sub-block on the `followup_email` task's
> `context`) and is folded into the follow-up email by `draft-followup`. A plan never carries a
> discrete scheduling task.

### Registry rules

The artifact states these rules; the loop and the synthesizer honor them.

- **Closed, canonical set (FR4).** This table is the **closed, canonical** set of task types Unbound
  recognizes (FR1). Adding a type means adding a row here (and a handler if it executes) — there is
  no second authoritative list. `work-account` emits only types in this table; `run-unbound` dispatches
  only on types in this table.
- **`mode` defaults to `define-only` (FR16).** A row with no explicit `execute` is `define-only` and
  is **never executed** — the loop never walks it; it stays documented in the plan and surfaces in
  the close-out recap as a rep-owned action item.
  Only `execute` rows name a handler (FR3) and an `invocation` policy; `define-only` rows leave both
  blank. An absent or unrecognized `mode` is read as `define-only` (define-only-by-default holds by
  construction).
- **`invocation` defaults to `per-task`, surfacing a malformed value (NFR8).** On `execute` rows
  only, `invocation` sets artifact cardinality: **`per-task`** (the handler runs for every accepted
  task — N tasks → N artifacts) or **`once-per-run`** (the handler runs at most once per item per run
  — N tasks → 1 consolidated artifact; the handler self-folds its sibling tasks). When `invocation`
  is **absent or malformed** on an `execute` row, it **defaults to `per-task`** — the conservative
  default that never silently skips an accepted task — and the **malformed value is surfaced**, not
  swallowed. `define-only` rows leave `invocation` blank.
- **Unknown type → define-only `internal`, no fabrication (FR10).** A `type` matching **no** row is
  handled as `define-only` (surfaced as `internal`). The loop **never invents** a handler, an
  artifact, or a type to cover an unknown value (NFR5) — it documents the task honestly and moves on.
- **Declares *whether*, never *how* gated (FR14).** A row declares only the type's execution `mode`
  (and, when `execute`, its handler and invocation). It says **nothing** about *how* a type is
  approval-gated. The approval gate is owned once by `run-unbound`'s loop — the Step 3.5 triage —
  and applied uniformly to every `execute` type (ADR-12 / D6); the registry neither restates nor varies it.

### Activation and addition (neither touches `run-unbound`'s loop)

- **Activation** (`define-only` → `execute`): flip the row's `mode` to `execute` and name a
  conforming handler (one that honors Part B), plus an invocation policy. The handler skill
  lives in the **`handlers/` subfolder** (`unbound/skills/handlers/<name>.md`); the bundle build
  resolves it by `name` automatically. That is the whole change for turning a type on (FR5).
- **Addition** (a new type): add a row to this table (and a handler under `handlers/` if it
  executes) (FR6).

Neither activation nor addition edits `run-unbound`'s loop. The loop reads `mode` and `invocation` as
**data** and never names a type, so extension locality holds (NFR1) — the change lives in the
registry (+ a handler), never in the loop.

> **Worked example — activating a `per-task` type later.** Turning on decks is the same one-row
> change: `| create_deck | a deck to create | execute | draft-deck | per-task | ideate_content |`.
> Because `invocation` is declared **data**, two `create_deck` tasks in one plan correctly yield
> **two** decks — with **no** edit to `run-unbound`'s loop.

### Client overlays (registry-ext)

A maintainer deploying Unbound for a client that needs **client-specific** task types adds them in a
**client overlay** — a `registry-ext.md` file the client owns — instead of editing this shared
canonical file. The overlay composes onto core; core stays immutable and re-pinnable.

- **Row shape (identical to Part A).** An overlay row carries the **same six columns in the same
  order** as the Part A table: `type` | description | `mode` | handler | `invocation` |
  expected `proposed_action`. Every registry rule above (mode-defaults, invocation-defaults,
  unknown-type handling, declares-*whether*-never-*how*) applies to an overlay row unchanged — an
  overlay row is a registry row that happens to live in the client's file.
- **Merge rule (composed closed set).** The composed vocabulary is **core ∪ overlay**: the union of
  this file's Part A and the client's `registry-ext.md`. That union — not core alone — is the
  **closed** set (FR4 generalized to a *closed composed set*). `run-unbound` dispatches on it and
  `work-account` derives its enum from it; a type outside the union is still an unknown type.
- **Core immutability (strictly additive).** Composition is **additive only**. An overlay MUST NOT
  redefine a core `type` (a type equal to any Part A `type` is a hard collision, not an override),
  and MUST NOT reuse a core skill name for a handler (handlers live in the client's own pack). Because
  core is never mutated, the client-upgrade story is a **re-pin + re-lint**, never a merge.
- **Conformance obligation (execute rows).** Every `execute` overlay row names a `handler` present in
  the client's own `skills/` pack, and that handler **honors Part B** (the Handler Contract) exactly
  as a core handler does. A `define-only` overlay row leaves handler and invocation blank, same as core.

---

## Part B — Handler Contract (the "skill-like structure")

This contract is **self-contained**: a contributor can build a conforming `execute` handler from
**this section alone** (FR20). `draft-followup` is the **worked reference example** of the contract,
**not** the spec — read it to see the contract realized, but the contract below is the authority.

Every `execute` handler MUST honor the following.

### Receives (FR17)

The loop invokes the handler passing, every time:

- **`selected_item`** — the one item being worked (`{ namespace, slug, context_ref, evidence[] }`),
  **including its `evidence[]`** (the per-`(namespace, slug)` union of source-discriminated grounding
  artifacts — call transcripts and/or email bodies — assembled by the orchestrator).
- **The full `work-account` output** — `tasks[]`, `open_questions[]`, and `next_step` — as
  **read-only grounding**. The handler never re-ranks, re-suppresses, re-annotates, or re-decides any
  of it.
- **`source_task`** — the reached task that triggered this invocation (the specific `tasks[]` entry
  the loop is handling at this turn).

### May read (read-only grounding)

Beyond what it receives, the handler may read: the item's `context.md`; `company/*` (e.g.
`messaging.md`, `assets.md`, `process.md`); `state/run-state.yaml` (e.g. the run's `timezone`); and
declared **read-only logical capabilities** (e.g. `content.search` / `content.get`,
`calendar.availability`). It names a **logical capability**, **never a concrete tool** (ADR-6) — the
runtime resolves the binding.

### May write (FR18) — local drafts only

- The handler may write **only a local draft** under the item's `drafts/`
  (`accounts|projects/<slug>/drafts/…`). It creates `drafts/` if missing; it never writes to the repo
  root or to `company/`.
- It performs **no external send or queue** and treats **all external systems as read-only** (ADR-4)
  — no email is ever sent or queued; Drive, Calendar, CRM, etc. are read-only.
- It introduces **no new writer**. Feedback and plan-file writes route through `work-account`'s
  shared `capture-feedback` / `apply-edit` authorities (reused by name, never re-authored); the
  handler adds none of its own.

### Output edit (MUST — the artifact is worked to done, not just recorded)

Every `execute` handler that **writes an artifact** MUST author an
`apply-<artifact>-edit(namespace, slug, source_task, note)` procedure — authored once in the
handler that owns the artifact (it owns the file, so it owns the rewrite) and reused by name. The
procedure honors these steps **in this order**:

- (a) **Tie** the edit to the artifact this run wrote for the item, by the **latest-dated**
  authority rule; ask if ambiguous; when no such artifact exists, say so and write nothing.
- (b) **Bound** the edit to a field set the handler **declares explicitly** — never the whole file,
  and never any field that would send, queue, or rename.
- (c) **Re-produce** the content honoring the handler's **own content contract**: an edit re-runs
  that contract, it does not bypass it.
- (d) **Rewrite the artifact file FIRST**; on a write failure, report it and log **nothing**.
- (e) **Only then** append exactly **one** `edit` line via `capture-feedback` (the shared authority,
  reused by name) with the rep's text verbatim as `note`.
- (f) **Re-present** the revised artifact and confirm tersely; the rep's next verdict continues the
  loop.

One log line **per cycle**, append-only — a changed mind is a new line, never a rewrite. The loop is
**rep-bounded by construction**: every cycle requires a rep turn, so no handler-side iteration and
no cycle cap is needed or permitted. Accept ends it; silence ends it with nothing further written,
the artifact at its last applied state, narrated honestly as abandoned rather than as accepted.

The obligation is on **applying** the edit, **not** on any render capability — a handler presents
its artifact on whatever surface its pack defines, falling back to the cited filename plus the
content in chat. **No new logical capability is introduced** by this clause, and no new writer: the
one file the procedure rewrites is the artifact the handler already owned under `drafts/`.

### May assume (gate precondition, FR19)

- The handler is invoked **only after an accept** (or accept-after-edit) collected in
  `run-unbound`'s **plan-triage submission**. It may **assume** that accept has happened.
- It **never drafts or acts absent that accept**, and it **never re-implements gating** — the gate is
  owned once by the loop (ADR-12). On a reject or no-verdict the loop simply never invokes the
  handler.
- Only the **collection point** moved (from a per-task checkpoint to the one batch triage
  submission); the guarantee itself is unchanged.

### Trigger contract (verify, then no-op cleanly on mismatch)

Before doing any work the handler verifies its **trigger contract**: that `source_task` matches the
handler's `type` **and** carries the **expected `proposed_action`** for that type (per the Part A
row — e.g. `followup_email` ⇒ `draft_email`). If the contract does **not** hold (wrong type, or a
`proposed_action` that doesn't match), the handler **no-ops cleanly**: it writes nothing, touches no
`drafts/`, states briefly in chat that no action was warranted, and hands back.

### Invocation behavior (per its registry `invocation` value — ADR-13 / D4)

The handler behaves consistently with the `invocation` value its Part A row declares:

- **`once-per-run`** — the handler **self-folds its sibling tasks** of the same type for this item
  into **one** consolidated artifact (it collects the other same-type tasks in `tasks[]` as material,
  never a second artifact), and is **idempotent-by-date** (re-running the same day rewrites that
  day's file). *(Example: `draft-followup` folds every `followup_email` ask into one email per item
  per run.)*
- **`per-task`** — the handler acts **only on its `source_task`** (N accepted tasks of the type →
  N invocations → N artifacts). It does not self-fold or fan out.

### Turn accounting (the loop's obligation, not the handler's)

The **loop** records which tasks it has already given a turn. After a handler hands back — whether
it wrote an artifact **or** no-oped cleanly on its trigger contract above — the loop marks that
turn on the `source_task`, and for a `once-per-run` type it marks each folded sibling at its own
turn. A clean no-op still spends the turn, so it is still marked; that is what stops the same task
being offered again forever.

The handler's side of this is **nothing at all**: it never writes the marker and never reads it. A
handler must not branch on whether a task was handled before, must not skip work because a marker
exists, and must not set one to signal that it finished — handing back **is** how it reports
completion. Where a handler's `apply-<artifact>-edit` re-runs on an already-handled task, that
changes the **artifact**, not the marker: the turn was consumed once and stays counted once, which
is why the Output-edit clause above needs no amendment.

This clause is **additive**. No existing handler becomes non-conforming by it, and a client pack
conforms **by doing nothing** — the obligation sits entirely on the loop.

### Returns

The handler handles **one** task end-to-end for the one item, then **hands back to the loop**. It
**never fans out** to other items and never advances the loop itself.

### Reference example (not the spec)

`draft-followup` (at `unbound/skills/handlers/draft-followup.md`) is the worked example of this
contract — the `followup_email` handler, `execute` / `once-per-run`, triggered on
`proposed_action: draft_email`, writing one local email draft under `drafts/`. Its
**APPLY-DRAFT-EDIT** is likewise the worked example of the Output-edit clause: bounded to `to[]` /
`subject` / `body`, draft file rewritten first, one `edit` line logged only on success, re-rendered
for a fresh verdict. Read it to see the contract in practice; build new handlers from **this
contract**, not from `draft-followup`.

---

## Distribution and current consumers

This file is the **declarative authority**; dispatch behavior lives in `run-unbound`'s loop, which
reads it. Where each consumer stands today:

- **`run-unbound` Step 4** — dispatches per this registry by pointer and embeds no copy of the
  Part A table; this registry is the sole statement of the type set. Step 4 now dispatches over
  **accepted** tasks only — the approval gate moved to `run-unbound` Step 3.5. Unchanged either
  way: this artifact declares *whether* a type executes, never *how* it is gated.
- **`work-account`** — derives its `type` enum from Part A and emits only types in it; it asserts
  no independent list.
- **`draft-followup`** — the reference `execute` handler, conforming to Part B; lives at
  `unbound/skills/handlers/draft-followup.md`.
- **`.claude/skills/` mirror + cowork bundle** (`dist/cowork-skills/`) — this artifact ships to both
  via `runtime/build-cowork-bundle.sh`: a mirror entry on Claude Code and `resources/task-registry.md`
  inside `run-unbound.zip` on Cowork. Rebuild after any edit here; `--check` guards drift.
