# Tool Bindings — Demo Runtime (fixture-backed)

> **What this file is.** The single source of truth mapping each **logical capability** a skill may call to the
> resolution that satisfies it in the **demo runtime**: a read of a committed local fixture for external data, and the
> runtime's own interactive surface for render/capture. It is the file `build-cowork-bundle.sh --tier demo` selects in
> place of `runtime/tool-bindings.md` when it assembles the demo artifacts (wired in Story 2.3), and it is the **entire**
> behavioral difference between the demo and the live product (ADR-6 / Pattern 4). Nothing under `skills/` changes.

## The indirection rule (ADR-6)

- Skills under `skills/` reference **only logical capability names**; they never name a concrete tool, and they never
  learn that this runtime's data is fixture data. Every concrete resolution lives in this file.
- Porting = one bindings file; nothing under `skills/` changes (Pattern 4). The demo tier **is** that port, exercised at
  **build time** rather than at runtime: the build swaps this file in, and all sixteen capabilities re-point at
  committed local data and local surfaces with **zero skill edits**.
- **Parity is the anti-rot contract.** The capability-name set in this file's three binding tables is **identical** to
  the set in `runtime/tool-bindings.md` — sixteen names, de-duplicated across the tables. When a capability is added to,
  removed from, or renamed in the live file, the same change lands here in the same commit; otherwise this file becomes
  a shadow that silently under-reports (see `## render.connections`, which derives its checklist from these tables).
- Cross-runtime equivalents deferred — as in the live file, every binding below covers this runtime plus its documented
  fallback only.

## Security posture (ADR-4)

All external-data bindings are **read-scope only**, and more strictly so here than in any connected runtime: the six
fixture-backed reads are **local file reads** of files committed inside the artifact — no network call, no credential,
no authorization prompt, no external server, and no connector of any kind is contacted at any point in a demo run. No
external write scope is requested or configured anywhere in this file. The one **declared future write gate**
(`crm.write`, below) stays **NOT BOUND** exactly as it is in every other runtime — the external write boundary is closed
by ADR-4, not by this tier, so nothing a presenter does during a demo can reach a real system. The eight `render.*` /
`review.collect` capabilities are **local render/capture surfaces, not external reads or writes**: none introduces a new
writer or write scope; the only writes they can lead to are the existing local authorities in
`skills/pipeline/work-account.md` — SET-STATUS, `capture-feedback`, and APPLY-EDIT — plus, for the setup-time
`review.collect` item kinds, the invoking skill's local file write (see `## review.collect`). Nothing under
`resources/demo/` is ever written by any capability.

## Binding table — external reads

Every resolution below is a `Read` of a file staged at `resources/demo/fixtures/` inside the built artifact. Paths are
written **bundle-relative** because this file is only operative inside a build; when verifying them in the repo, map the
`resources/demo/` prefix onto `runtime/demo/`. **Per invariant D2 the fixture tree is bundled only inside
`run-unbound-demo`'s artifact**, because every external-data consumer (composition steps 1, 2 and 7) ships there — so
`collect-tasks-demo`, `connect-tools-demo` and `setup-unbound-demo` receive this same bindings file **without** the
fixture data, and a fixture-backed read reached from one of those skills finds nothing and degrades honestly rather
than inventing a result.
Widening the fixture set into another skill's artifact is a packaging change, not a bindings change.

| Logical capability | Scope | Demo resolution (local read) + invocation detail | Consumed by |
| --- | --- | --- | --- |
| `calendar.list_events_since(ts)` — `ts` is an ISO-8601 timestamp | read | `Read resources/demo/fixtures/calendar/events.json` — a fixed array of events. Return those whose `start` is **strictly after** `ts`, compared in the run `timezone`; no pagination, no second query, no other filter. Same `ts`, same events, every run. | `skills/pipeline/discover-events.md` |
| `calendar.availability(attendees, window)` — `attendees` = the rep + the named stakeholders; `window` = start/end ISO 8601, resolved in-skill; bounded to one lookup per draft. Honest degradation: unreadable attendee → rep-only slots phrased as offers to confirm; capability unavailable → the meeting ask carries no concrete times | read | `Read resources/demo/fixtures/calendar/freebusy.json` — a map from attendee email to that attendee's **busy** blocks. Open slots are derived **in-skill** (pure date math: `window` minus busy, in the run `timezone`), exactly as in the live runtime. An attendee **absent from the map is unreadable** — degrade to the readable attendees' (at minimum the rep's) open slots, phrased as offers to confirm, and **never guess** a free block for an unmapped attendee. | `skills/handlers/draft-followup.md` (AVAILABILITY) |
| `transcript.get(call_ref)` — `call_ref` is the opaque key carried forward from the calendar event | read | `Read resources/demo/fixtures/transcripts/index.json` and look `call_ref` up **once** — a single key lookup with **no fan-out**, no correlation search, no ranking, no second source. On a hit, the entry's `transcript_file` value is resolved **relative to the fixtures root** (join it to `resources/demo/fixtures/`) and read for the body; return `{ text, provider }` with `provider` carried **verbatim** from the entry. On an entry of `{"missing": true}` — **or on no entry at all** — return `missing`; never fabricate, never infer. | `skills/pipeline/fetch-transcript.md` |
| `content.search(query)` — returns opaque `ref`s | read | `Read resources/demo/fixtures/drive/index.json` — return the `ref`s whose `name` or `terms` match `query` by **case-insensitive substring**, in index order. Bounded exactly as live: one search per draft, to verify existence — never an index crawl. | `skills/handlers/draft-followup.md` (MATCH-ASSET), `skills/setup-unbound.md` (asset intake — no fixture data in that artifact, per D2 above) |
| `content.get(ref)` — resolves a `ref` to its content | read | `Read resources/demo/fixtures/drive/<ref>.md` — the one body file for exactly that `ref`, one read. An **absent** file is an honest not-found: MATCH-ASSET reports `none` and the draft proceeds with no asset named; nothing is substituted, summarized from the index, or invented. | `skills/handlers/draft-followup.md` (MATCH-ASSET), `skills/setup-unbound.md` (asset intake + asset-link verification) |
| `web.fetch(url)` — resolves a public web page URL to its readable content | read | **No fixture — deliberately unbound in this runtime.** Fetching a URL would be a network call, which this runtime does not make, and a fixture would be a page the presenter never actually fetched. **Optional-degraded:** the capability reports itself **unavailable** ⇒ the website intake path is unavailable, stated plainly to the user; setup proceeds via files shared in chat, the asset index, or the interview. Nothing is fetched and **nothing is simulated**. | `skills/setup-unbound.md` (website intake) |
| `email.list_unanswered_threads(ts)` — all thread fields carried verbatim: `thread_ref` (opaque correlation key), `subject`, `participants[]` (`{ name?, email? }`), `last_message_at` (ISO 8601 with offset; compared in the run's `timezone`, never reformatted); `latest_external_message_body` is inline | read | `Read resources/demo/fixtures/email/threads.json` — return the threads whose `last_message_at` is **strictly after** `ts`, compared in the run `timezone`. The **hard pre-filter** (inbox-only; promotional, social, automated, spam and trashed traffic excluded; the rep has not replied last) is **baked into the fixture authoring**, so this binding issues no query of its own and the skill never re-applies it. | `skills/pipeline/discover-events.md` |
| `email.get_thread(thread_ref)` — get-by-ref: resolve ONE stored `thread_ref` to its thread, for evidence recovery on a later run. Same thread shape as the list capability; no window and no search | read | `Read resources/demo/fixtures/email/threads.json` and look `thread_ref` up **once** — a single key lookup with **no window filter**, no search and no ranking, which is exactly why recovery here is window-independent. On a hit, return that thread entry verbatim. On **no entry at all**, return `missing`; never return a nearest-match thread, never fabricate a body. | `skills/pipeline/fetch-transcript.md` (evidence recovery) |

> **Determinism, not simulation.** These files are fixed and byte-stable; the same `ts` produces the same result on
> every showing. The binding applies the stated filter and nothing else — it never fills a gap, never synthesizes a
> record, and never softens a `missing` into a guess. Where the fixture data has nothing to give, the consuming skill
> takes its documented degraded path, which is the same path it takes against a live source that returns nothing.

## Binding table — render/capture surfaces

All eight resolve interactively on the runtime's own **widget render surface**, each pinned to the template named in its
row — layout minutiae live in the template, never in prose. In this runtime the surface is treated as present at every
beat: see `## Demo widget rule — ALWAYS RENDER` below, which supersedes the confirm-first resolution rule that follows
it. Templates are referenced in the live file's `runtime/templates/<name>.html` form so the two files stay diffable;
only fixture and prerendered paths — the genuinely demo-only, genuinely read-at-runtime ones — are bundle-relative.

| Logical capability | Scope | Interactive surface (pinned template) | Fallback | Consumed by |
| --- | --- | --- | --- | --- |
| `render.tasks(task_view)` | render, no capture | card stack, one card per task — `runtime/templates/task-plan-widget.html` | plain Markdown checklist in chat | `skills/pipeline/work-account.md` (re-render after SET-STATUS / APPLY-EDIT), `skills/standalone/collect-tasks.md` (roundup) |
| `review.collect(checkpoint_view)` | render/capture (local verdicts only) | **batch:** triage card stack with per-card controls, one submit — `runtime/templates/batch-triage-widget.html`; **single-item:** checkpoint card, one item per call — `runtime/templates/checkpoint-widget.html` | in-chat `accept \| edit \| reject` prompt per item | `skills/run-unbound.md` (Step 3.5 batch triage + Step 3.5 material-edit re-confirm + Step 5 close-out open questions) |
| `render.slate(slate_view)` | render, no capture | card grid, one card per derived group of pending events — `runtime/templates/slate-widget.html`. **Prerendered match-guard:** when this run's assembled slate is exactly the seeded five-item slate — the five slugs `brightwater-media`, `marlin-bay-cruises`, `halvorsen-pike`, `calla-vale`, `goldspire-resorts`, carrying the per-row signal shape call / call / call / email / call+email, goldspire's call pill ending in the verbatim `" · no recording"` marker, calla-vale's email pill reading `1 unanswered email`, every rendered signal date falling in the absolute-`Mon DD` band (all row dates ≥ 30 days before now), and every seeded event `pending` **and** no `work[]` records — serve `resources/demo/prerendered/slate-widget.html` **verbatim**. On **any mismatch, and equally on that file being absent**, assemble the card grid live from `runtime/templates/slate-widget.html` instead (see the note below) | plain annotated slate lines | `skills/pipeline/build-slate.md` Step 4 (via `run-unbound` Steps 2–3) |
| `render.email_draft(draft_view)` | render/capture (the draft's own verdict) | mail-client preview carrying an Accept / Reject / free-text-edit verdict footer — `runtime/templates/email-draft-widget.html` | cited filename + draft body in chat, with the same three verdicts invited in chat | `skills/run-unbound.md` (Step 5 combined output gate) |
| `render.crm_update(crm_view)` | render, no capture | informational CRM card — `runtime/templates/crm-update-widget.html` | plain in-chat "CRM Updates (simulated)" Markdown section | `skills/pipeline/write-crm.md` (APPLY — simulate branch) |
| `render.connections(connections_view)` | render, no capture | capability status board capped by the readiness banner — `runtime/templates/connections-widget.html` | plain Markdown capability table + verdict line in chat | `skills/standalone/connect-tools.md` (both entries) |
| `render.setup_progress(progress_view)` | render, no capture | section checklist card — `runtime/templates/setup-progress-widget.html` | plain Markdown section-status list in chat | `skills/setup-unbound.md` (progress + resume + audit views) |
| `render.context_preview(preview_view)` | render, no capture | formatted artifact preview (positioning block / stage-ladder pipeline / asset table) — `runtime/templates/context-preview-widget.html` | plain Markdown artifact section in chat | `skills/setup-unbound.md` (section-loop previews) |

> **The match-guard self-heals, and absence is a permanently supported state.**
> `resources/demo/prerendered/slate-widget.html` is present and captured from the seeded slate. Should it ever be
> absent — removed, unreadable, or not staged into a given artifact — the guard's absence branch is the branch that
> runs: the slate assembles live from its template and the demo is whole. That is not a phase the capture ended; it is
> the standing contract. Absence and mismatch are the **same** route by design: a guard that only handled mismatch would
> leave the run's first big visual beat dead whenever the capture is missing or the data has moved on. The predicate is
> deliberately written against the slate's **shape and recency regime** — the five slugs `brightwater-media`,
> `marlin-bay-cruises`, `halvorsen-pike`, `calla-vale`, `goldspire-resorts`; the per-row signal shape
> call / call / call / email / call+email; goldspire's call pill ending in the verbatim `" · no recording"` marker;
> calla-vale's email pill reading `1 unanswered email`; every rendered signal date falling in the absolute-`Mon DD` band
> (all row dates ≥ 30 days before now); and every seeded event `pending` **and** no `work[]` records — and not against `call_type` text, so re-authoring
> a call type changes the rendered subtitle without silently arming a stale prerendered file. The recency-regime clause
> is what turns the demo anchor's permanence into a guarantee rather than luck: the fixtures are dated 2026-06-19 →
> 2026-06-23, so the `d ≥ 30` band routes every row to the absolute `Mon DD` form the capture holds — and should anyone
> re-anchor the corpus to recent dates, that clause fails cleanly, the slate assembles live, and the cost is one
> render's latency instead of shipping wrong text. If any element of the predicate does not hold exactly, assemble live.

## API contract — logical capability signatures (stable across runtimes)

Per `notes/architecture.md#API-Contracts`; the signatures are **runtime-invariant** — only the binding tables above
change per runtime, which is why this block reads almost identically to the live file's. Render view shapes live in
their capability sections below.

```
calendar.list_events_since(ts)  -> [event]               # read
calendar.availability(attendees, window) -> [open_slot]  # read; open_slot = { start, end } (ISO 8601 with offset, in the run's timezone); an attendee whose free/busy is unreadable is reported unreadable, never guessed
transcript.get(call_ref)        -> { text, provider } | missing  # read; single deterministic index lookup in this runtime — no fan-out, no ranking; `provider` carried verbatim from the matched entry; `missing` => never silently drop (Pattern 2)
content.search(query)           -> [ref]                  # read
content.get(ref)                -> content                # read
web.fetch(url)                  -> page_content | unavailable  # read; optional-degraded — unbound here, so always unavailable => website intake unavailable (stated), setup proceeds via files/assets/interview
email.list_unanswered_threads(ts) -> [thread]            # read; threads where the rep has not replied last
                                                          # thread = { thread_ref, subject, participants[],
                                                          #            last_message_at (ISO 8601 with offset),
                                                          #            latest_external_message_body }
email.get_thread(thread_ref)    -> thread | missing       # read; single deterministic key lookup in this runtime — no window, no
                                                          # search; an unmatched ref => missing (Pattern 2 — never fabricated)
render.tasks(task_view)         -> interactive_checklist | markdown_checklist   # render, no capture
review.collect(checkpoint_view) -> verdicts                                     # render/capture; verdicts route to capture-feedback
render.slate(slate_view)        -> slate_cards | annotated_lines                 # render; interactive card grid, fallback = plain annotated slate lines
render.email_draft(draft_view)  -> { preview, item_verdict }                     # render/capture; interactive mail-client preview + verdict footer, fallback = cited filename + body in chat with the verdict invited in chat
render.crm_update(crm_view)     -> crm_card | markdown_block                     # render; informational CRM-update card, fallback = plain in-chat "CRM Updates (simulated)" Markdown section
render.connections(connections_view) -> connections_board | markdown_table       # render, no capture
render.setup_progress(progress_view) -> progress_card | markdown_list            # render, no capture
render.context_preview(preview_view) -> artifact_preview | markdown_section      # render, no capture
crm.write(crm_update)           -> synced_confirmation | simulate                # write (future, UNBOUND — Epic G); unbound ⇒ documented fallback = simulate (persist local draft + render.crm_update). Never assume a write surface.
```

## Demo widget rule — ALWAYS RENDER

**Scope and precedence.** This rule applies to **this runtime's bindings only**. It **supersedes** the confirm-first
resolution rule in the section immediately below, and **overrides** it wherever the two disagree: where that rule says
"only on positive confirmation", this runtime says "treat the surface as present". A presenter holding an audience
cannot have a beat silently drop to Markdown because a capability probe was inconclusive.

- **The interactive render surface is present — do not re-decide that per beat.** At every render/capture beat named in
  the table above, render the widget. Do not confirm availability first, do not reason about whether a widget is
  warranted, and do not offer the fallback as a choice. The concrete surface is whichever widget-rendering tool the
  runtime exposes in its live tool list; select it from that inventory, never from prose in this corpus — concrete tool
  names enter a session from the environment, not from the skills (ADR-6).
- **One silent preamble per session.** If the surface defines a one-time introspection or capability-declaration step,
  run it **exactly once per session, silently, before the first widget** — no narration, no summary, no user-visible
  turn. A failed preamble does **not** block: proceed to render anyway.
- **The pinned template is the instruction.** Each row above names the template that pins its fragment. Assemble that
  template's fragment from the capability's view object and hand it to the render surface; the beat is rendered when
  that fragment has been handed over. The template carries the layout — never restate layout in prose, and never
  substitute a different template for a beat.
- **Failure is bounded and honest.** If a render call itself errors, render **that beat's documented fallback once**
  and continue the run — never retry in a loop, never silently skip the beat, and never present the error as the beat's
  content.
- **An empty slate still renders no widget.** The existing empty-slate chat line stands; "always render" governs beats
  that have something to show, and never manufactures one that does not.
- **Field parity is untouched (ADR-1).** Interactive and fallback surfaces carry identical content — no field dropped
  on one and invented on the other; an `inferred:` evidence/basis marker renders as-is on both, never dressed as a
  citation.

## Resolution rule — all render capabilities

In the live runtime, interactive mode is used only on positive confirmation that the widget-render tool is present, and
resolves to the capability's documented fallback otherwise — never assume rich UI; that confirmation is performed **once
per session** and its answer — including a cached **fallback**, which caching never upgrades into an assumed rich UI —
is reused at every later `render.*` and `review.collect` site rather than re-confirmed at each one. **In this runtime
that confirmation step is superseded by the ALWAYS RENDER rule above:** the surface is treated as present, interactive
mode is used at every beat, and the documented fallback is reached only by a surface error at that beat (rendered once,
per the rule). The two files therefore agree on the shape — the render surface is settled once for the session and never
re-decided per beat — and differ only in what settles it: live confirms the surface, this runtime asserts it.
Both modes carry the same content — no field dropped or invented on either surface (ADR-1); an `inferred:`
evidence/basis marker renders as-is, never dressed as a citation. Widget mechanics — the once-per-session preamble,
failure handling, fragment constraints, the self-describing sendPrompt grammar, and ADR-9 click-sends-prompt semantics —
are documented in `runtime/adapters/cowork.md`, which is a repo-side authoring reference that ships in no artifact; that
is exactly why the behaviors a run actually depends on are restated in logical terms in the ALWAYS RENDER rule above
rather than deferred to it.

## render.tasks

`task_view` = canonical tasks (`id`/`title`/`priority`/`type`/`status`/`evidence`), optionally grouped by item
`namespace/slug`. Presentation only: the cards carry **no checkbox and no buttons** — verdicts happen at the Step 3.5
`review.collect` triage; the card's evidence line shows the cited quote or the `inferred:` marker; the roundup
(`collect-tasks`) adds a status pill and groups cards under `namespace/slug` headers. `render.tasks` conveys nothing
back and introduces no writer — task status changes are explicit chat asks applied via SET-STATUS, the single status
write authority. Display labels are presentation-only (`not-done → "open"`, `done → "done"`, `deferred → "deferred"`;
Markdown fallback: `- [x]` done, `- [ ]` otherwise); the persisted enum `not-done | done | deferred` is never changed by
rendering. **Every surviving call site renders in this runtime** — `work-account`'s post-SET-STATUS / post-APPLY-EDIT
re-renders and `collect-tasks`' roundup — exactly as production does; suppressing any of them would make the demo
describe a product that is not the one being sold. The plan step itself no longer renders here: the first rep-facing
task surface is the Step 3.5 triage card stack (see `## review.collect`).

## review.collect

`checkpoint_view = { items[], open_questions[] }`; each `item = { task_id, title, rationale, evidence, context?, kind:
"task" | "context_section" | "binding_change", body? }` — `context` is the task's typed
execution-context block on `kind: "task"` items. The produced email draft is **not** an item kind here: it carries its
own verdict on its own surface (see `## render.email_draft`). Returns `verdicts = { item_verdicts[], open_answers[] }`;
`item_verdict = { task_id, verdict ∈ {accept|edit|reject}, note }`; `open_answer = { question, answer }`.

**Call-site policy — batch or single-item, fixed per site.** `items[]` was always a list; which mode a site uses is
settled here, never chosen by the caller:

| Call site | Mode | `items[]` | `open_questions[]` |
| --- | --- | --- | --- |
| `run-unbound` Step 3.5 — plan triage | **batch** | all retained tasks, in priority order | `[]` |
| `run-unbound` Step 3.5 — material-edit re-confirm | single-item | the one re-shaped task | `[]` |
| `run-unbound` Step 5 — close-out open questions | no items | `[]` | this run's list (skip the call entirely when it is empty) |
| `setup-unbound` — `context_section` | single-item | one previewed section | `[]` |
| `connect-tools` — `binding_change` | single-item | one proposed row edit | `[]` |

A **batch** return simply carries N `item_verdict`s. **An omitted `task_id` in a batch return is an omitted verdict** —
silence stays per-task inside a batch, and nothing is written for a card the rep never touched. A batch of one is still a
batch (same surface, same grammar — no reversion to the single-item card); **zero retained tasks means no call at all**
(never render an empty checkpoint). Card text rules: the Evidence label is source-prefixed (`Evidence · email (<name>)` /
`Evidence · call (<call_type>)`); the verdict-prompt strings are the render surface's sendPrompt grammar. The batch card
carries P# badge, type pill, title, rationale, and one source-prefixed evidence line and **omits the typed `context`
block** (progressive disclosure — depth belongs to the output gate); the single-item card keeps its two-column context
grid, whose labels vary by task type.

Verdict mapping: Accept → `accept`; Reject → `reject`; a free-text edit → `edit` with the text captured **verbatim** as
`note`. **No answer for an item → no verdict for that item** (silence is not a verdict); hand-typed equivalents map
identically; ambiguous free text that cannot map to the enum → ask, never an out-of-enum write. Verdicts route through
the existing write authorities — no new writer: one `capture-feedback(namespace, slug, task_id, verdict, note)` line per
verdict to `state/feedback-log.jsonl`; a **task** `edit` is applied via work-account's APPLY-EDIT (an **output** `edit`
is applied by the artifact's own handler — see `## render.email_draft`); verdicts never touch task `status`
(SET-STATUS's domain). `open_questions[]`
are **never widget-rendered** — they remain in-chat free text; `open_answers[]` are surfaced only — echoed in chat,
nothing written.

Setup-time item kinds (outside the run loop): `context_section` — the item is one previewed context section, its
`task_id` slot carrying the section id (`process | messaging | assets | state`); consumed by `skills/setup-unbound.md`
(section verdicts, state-init confirm, refresh proposals). `binding_change` — the item is one proposed row edit to this
file; consumed by `skills/standalone/connect-tools.md`. One item per call, never batched, and the
`accept | edit | reject` enum are unchanged. **Routing outside the run loop:** accept ⇒ the invoking skill performs its
local file write; edit ⇒ the note is applied to the draft/proposal and re-presented; reject ⇒ the section is re-entered
/ the proposal dropped. **No `feedback-log.jsonl` line is written** — `capture-feedback` remains exclusively the run
loop's prioritization instrument. Note that in this runtime a `binding_change` item has no writable target: this file
ships inside the built artifact, so `connect-tools` reports rather than proposes (see `## render.connections`).

## render.slate

`slate_view` = the annotated groups of pending events `build-slate` Step 4 assembles (name, namespace, stage-if-known,
call fields, email fields, transcript flag, plus the display strings its label-derivation rules produce — subtitle and
recency labels; nothing is re-derived at render time). Pure render; selection stays rep-owned. Pill text rules: call
pill `"Call · <recency>"`, appending `" · no recording"` **verbatim** when the row's evidence flag is `missing`,
and appending **nothing** when it is `unknown` — no clause, no placeholder, no dangling `·`, because nothing is fetched
before selection and an absent fact yields an absent label. `unknown` is never rendered as `present` or as `missing`.
Email pill `"<N> unanswered email<s> · <recency>"`; both-signal rows show both pills, call pill first; an absent date
omits the recency clause entirely — no dangling separator. The muted subtitle reads
`<Humanized stage> · <Humanized topic>`, or whichever single part is known, or the humanized namespace singular
(`Account` / `Project`) when neither is. The full-width
**`Work <Name>`** button (name with `&`/punctuation flattened to words) is the selection utterance: the click writes
nothing and sends that text as the rep's selection turn, matched exactly as if typed (case-insensitive; ambiguity →
ask) — `render.slate` causes no write of any kind. An **empty slate renders no widget** (the existing "empty slate" chat
line stands); the `dropped` set is **never** widget-rendered.

**Match-guard evaluation order, in this runtime.** (a) Assemble `slate_view` normally — the guard never changes what
the slate *is*, only how it is drawn. (b) Test the seeded predicate stated in the binding row above — the five slugs
`brightwater-media`, `marlin-bay-cruises`, `halvorsen-pike`, `calla-vale`, `goldspire-resorts`; the per-row signal
shape call / call / call / email / call+email; goldspire's call pill ending in the verbatim `" · no recording"`
marker; calla-vale's email pill reading `1 unanswered email`; every rendered signal date falling in the
absolute-`Mon DD` band (all row dates ≥ 30 days before now); and every seeded event `pending` **and** no
`work[]` records. (c) On an exact
match **and** a readable `resources/demo/prerendered/slate-widget.html`, pass that file's contents to the render
surface **verbatim** — no re-templating, no substitution, no per-run edit. (d) On any mismatch, or when that file is
absent or unreadable, assemble the card grid from `runtime/templates/slate-widget.html` and render that. Both paths
produce the same content from the same `slate_view`; the prerendered path only removes assembly latency from the run's
first visual beat. The prerendered file is captured from the seeded slate and ships in `run-unbound-demo`'s artifact; path
(d) remains the permanent, expected, fully supported behavior for every run in which the predicate does not hold
exactly — including any future one in which a fixture change legitimately makes the capture stale.

## render.email_draft

`draft_view = { to[], subject, body, filename }`, read from the draft file `draft-followup` already wrote under the
item's `drafts/` — nothing is regenerated or altered at render time. **Render/capture:** the preview carries a
**verdict footer** — Accept / Reject buttons plus a free-text edit input and Submit — and returns the draft's
`item_verdict = { task_id, verdict ∈ {accept|edit|reject}, note }`, where `task_id` is the draft's `source_task`. The
draft and the decision on it are **one surface**; no separate checkpoint card follows it, and the verdict strings are
the **existing** per-item sendPrompt grammar — no second grammar exists. The amber `draft · not sent` pill states the
boundary the footer does not move: nothing is sent, queued, or renamed. In this runtime that boundary is structural as
well as stated: no capability in this file can reach a mail system at all. The draft's filename is cited in chat
alongside the widget.

An **`edit` verdict is applied**, not merely recorded: `draft-followup`'s `apply-draft-edit(namespace, slug,
source_task, note)` rewrites the draft file — bounded to `to[]`, `subject`, `body` — **first**, appends exactly one
`edit` line via `capture-feedback` **only** on success, and re-renders through this capability so a fresh verdict is
collected. The cycle repeats until accept or abandon; one log line per cycle, append-only, and it is rep-bounded — each
cycle takes a rep turn. Silence after a re-render writes nothing and leaves the draft at its last applied state. This
capability adds **no** writer: the draft file is one `draft-followup` already owned, written into the demo workspace
exactly as production writes it.

## render.crm_update

`crm_view` = the in-memory `crm_update` object `work-account` Step 6.5 handed back (`current_stage`,
`stage_recommendation { recommendation, to_stage, criteria[], unmet[], reason }`, the verbatim-carried `next_step`,
`product_gaps[]`) plus the persisted `drafts/YYYY-MM-DD-crm-update.md` `filename`; nothing is re-evaluated at render
time. **Informational only:** zero affordances, returns nothing; no `review.collect` call follows, no `capture-feedback`
line is written, and silence has no meaning here. Card text rules: exactly one recommendation pill —
`advance to <stage>` / `no change` / `not applicable — <reason>`; a met exit criterion carries its source-prefixed
citation, an unmet one reads `no evidence this run`, and the criteria block is **omitted entirely on `not-applicable`**;
the carried `next_step` renders in one line (or its explicit no-next-step reason); one cited bullet per product gap, or
the honest `none raised this run` line when empty. Because `crm.write` is **NOT BOUND** (below), this card is always
reached through `write-crm`'s **simulate** branch and always carries its "(simulated)" framing: the persisted filename
is cited in chat with the explicit statement that **nothing was written to any external system**. The stage
recommendation stays advisory — ENRICH remains the sole stage writer.

## render.connections

`connections_view = { capabilities[]: { capability, status: connected|missing|degraded, tool?, consequence },
verdict: { ready: true } | { ready: false, exceptions[]: { what, unlocks } } }` — the capability status board
`skills/standalone/connect-tools.md` assembles from its introspection pass (both entries); nothing is re-evaluated at
render time. `consequence` is the run-time cost of a gap in the honest-degradation voice, derived from this file's own
degradation notes. Board text rules: one status row per capability — the capability name, its status pill
(`connected | missing | degraded`), the serving resolution when bound, and the muted `consequence` line on
`missing`/`degraded` rows; the `verdict` banner closes the board — `READY TO RUN`, or `READY EXCEPT` with one
what/unlocks line per exception. **Render-only, conveys nothing back:** zero affordances, no verdict, no write.

**`connect-tools` in this runtime — what the readiness board honestly says.** `connect-tools` derives its required
capability set from **this file's own binding tables** (their logical-capability column *is* the requirement list,
including the declared future write gate), which is the second reason the sixteen-name parity above is load-bearing: a
capability missing from these tables simply stops being checked. Here those capabilities resolve to **bundled local
fixtures**, so the board reports them **"connected (local fixture)"** rather than flagging missing connectors — the
verdict is `READY TO RUN` with no connector, no credential and no network, which is the truth about this runtime, not a
courtesy. Two honest exceptions are reported as exceptions: **`web.fetch`** is **degraded / unavailable** — consequence,
website intake unavailable, setup proceeds from files, the asset index, or the interview; and **`crm.write`** is
**unbound** — consequence, CRM updates are simulated and drafted locally, never written to a CRM. One further
difference from the live runtime: `connect-tools`' propose step has no writable target here, because this bindings file
ships **inside** the built artifact rather than in an editable `runtime/` tree. In this runtime it therefore **reports**
— it does not propose row edits, and it never presents a `binding_change` item asking to edit a bundled resource.

## render.setup_progress

`progress_view = { mode: first-run|refresh|resume, sections[]: { id: process|messaging|assets|state,
status: done|active|pending | proposed-changes(n), coverage_note? } }` — the section checklist
`skills/setup-unbound.md` renders at its opening, after each section, on resume, and as the refresh audit view; nothing
is re-evaluated at render time. The section-id enum is fixed in D9 order (`process | messaging | assets | state`) — the
same enum `review.collect`'s `context_section` `task_id` slot carries. `coverage_note` is an optional muted annotation.
Card text rules: one mode line (`first-run | refresh | resume`) at the top; one row per section, in D9 order, carrying
the section name, its status pill (`done | active | pending | proposed-changes(n)`), and the muted coverage note when
present. **Render-only, conveys nothing back:** zero affordances, no verdict, no write — section verdicts flow through
`review.collect` items of kind `context_section`, never through this surface.

## render.context_preview

`preview_view = { section_id, drafted_content, provenance[]: { block_ref, label }, gaps[] }` — the drafted artifact
`skills/setup-unbound.md` previews in its section loop, before each verdict; nothing is regenerated or altered at render
time. `drafted_content` is the artifact **shaped like itself** — a positioning block for `messaging`, the stage-ladder
pipeline for `process`, the six-column asset table for `assets`. Provenance labels (`Evidence · <source> <locator>` /
`Answer · rep`) are a **preview overlay only, never written to files** — the accepted artifact strips them; gaps render
in the D13 blockquote voice and are the only overlay content that persists. **Render-only, conveys nothing back:** zero
affordances, no verdict, no write — verdicts belong to `review.collect` items of kind `context_section`.

## transcript.get (single-source)

- **Source set.** Exactly one source in this runtime: the committed `resources/demo/fixtures/transcripts/index.json`
  map. The live runtime's multi-provider fan-out, parallel correlation and confidence ranking are replaced by a single
  deterministic key lookup — there is no second source to rank against and no correlation search to issue.
- **Match policy.** `call_ref` is the opaque key `calendar.list_events_since` already carried forward, so no matching
  heuristic is needed: an entry carrying a `transcript_file` **is** the confident match. Read that value joined to the
  fixtures root and return `{ text: <verbatim transcript>, provider: <entry's provider> }`. An entry of
  `{"missing": true}`, or no entry for that `call_ref`, returns **`missing`** — the consuming skill marks the call
  `transcript: missing`, surfaces it to the rep, and never fabricates (Pattern 2). A surfaced gap is a feature of this
  corpus, not a defect in it.
- **One concurrency axis here, not two.** The live bindings describe two: a fan-out **across providers** within one
  `call_ref`, and a fan-out **across the independent events** of a selected item. The first does not exist in this
  runtime — a single deterministic key lookup has nothing to fan out across, which is exactly what the source-set swap
  removes. The second is **untouched by the swap**: `skills/pipeline/fetch-transcript.md` still issues the selected
  item's events concurrently under its own stated numeric bound, and each of those events simply resolves here as one
  index lookup instead of a provider sequence. The skill needs no demo-specific reading (ADR-6).
- **`provider` carried verbatim.** Taken **verbatim** from the matched entry — never rewritten, normalized, truncated,
  or case-round-tripped; never `null` on present, never present on `missing`; carried onto every `transcript: present`
  record. This file names **no** provider values: the fixture data is their only source here, exactly as the live
  environment is their only source there (ADR-6).
- **ADR-6 grep gate (load-bearing).** `skills/pipeline/fetch-transcript.md` and its mirror MUST contain zero concrete
  provider or tool names. Unchanged in force — the demo swap relaxes nothing.
- **Edge cases.** An unreadable or unparseable index is a read failure: name it and stop, never guess around it. A
  `transcript_file` that does not resolve is `missing` for that `call_ref` only, and leaves every other `call_ref`
  unaffected (Pattern 2).
- **Write boundary.** Both the lookup and the body read are read-only local file reads; nothing under
  `resources/demo/fixtures/` is written, ever.

## Binding table — declared future write gate (unbound)

> **Declared-but-unbound.** The one named future write capability, carried here with its documented simulate fallback so
> the boundary is explicit. It is **NOT BOUND** to any concrete tool **in any runtime** — that is ADR-4's closed write
> boundary, not a demo-tier limitation — and this row **requests and configures no write scope**. `connect-tools`
> derives it like any other binding row and reports it `missing`/`degraded` with the simulate consequence.

| Logical capability | Scope | Status / binding | Fallback | Consumed by |
| --- | --- | --- | --- | --- |
| `crm.write(crm_update)` — apply the field-level `crm_update` to the CRM (Growth / Epic G, FR28–FR34) | write (future) | **NOT BOUND** in any runtime — no concrete tool, no adapter row (write boundary closed, ADR-4) | **simulate** — persist the item's `drafts/YYYY-MM-DD-crm-update.md` + `render.crm_update` (informational); nothing written externally | `skills/pipeline/write-crm.md` (RESOLVE → APPLY — simulate branch) |

Binding `crm.write` is **deferred pending an ADR-4 amendment** (Epic G activation); until then `write-crm`'s RESOLVE
always selects the simulate fallback, because that branch is chosen by the **absence of a positive binding
confirmation** and no such confirmation exists. In this runtime that has a visible consequence worth stating plainly:
the run's CRM close-out beat always persists a local draft and renders the informational card headed **"(simulated)"**,
and no demo run can write to any CRM. `crm.read` / `crm.write_draft` remain in **Out of scope** below — `crm.write` is
the *named, still-closed* gate, not an opened write scope.

## Out of scope (do NOT add here)

- Any **external write-scoped** capability: `email.queue_draft`, `email.send`, `email.modify`, `email.label`,
  `crm.read`, `crm.write_draft` (Growth FR28–FR34). The mail source is list-and-read only in the discovery window —
  never send, reply, draft into the mailbox, label, archive, or modify.
- Bindings for other runtimes — deferred, per the indirection rule.
- Any capability name that is not in `runtime/tool-bindings.md`, and any omission of one that is: the two files carry
  the **same sixteen** capability names by contract (see the indirection rule above).
