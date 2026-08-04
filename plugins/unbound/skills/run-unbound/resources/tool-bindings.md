# Tool Bindings — Claude Cowork (MVP)

> **What this file is.** The single source of truth mapping each **logical capability** a skill may call to the **concrete
> MCP tool** that satisfies it on **Claude Cowork** — with `runtime/adapters/cowork.md`, the only runtime-specific surface
> (ADR-6 / Pattern 4).

## The indirection rule (ADR-6)

- Skills under `skills/` reference **only logical capability names**; they never name a concrete MCP tool. Concrete tool
  names live only in this file and `runtime/adapters/cowork.md`.
- Porting = one bindings entry/file + one adapter under `runtime/adapters/`; nothing under `skills/` changes (Pattern 4).
- Cross-runtime equivalents deferred — ChatGPT/Copilot bindings and adapters do not exist yet; every binding below covers
  the **Cowork** surface plus its documented fallback only.

## Security posture (ADR-4)

All external-data bindings are **read-scope only**; no external write scope is requested or configured anywhere in this
file — the external write boundary stays closed in the MVP (growth capabilities: "Out of scope"). The one **declared
future write gate** (`crm.write`, below) is documentation only: it is **NOT BOUND** to any concrete tool in any runtime
and requests no scope — it names the gate and its simulate fallback so the boundary is explicit, not open. The eight `render.*` /
`review.collect` capabilities are **local render/capture surfaces, not external reads or writes**: none introduces a new
writer or write scope; the only writes they can lead to are the existing local authorities in
`skills/pipeline/work-account.md` — SET-STATUS, `capture-feedback`, and APPLY-EDIT — plus, for the setup-time
`review.collect` item kinds, the invoking skill's local file write (see `## review.collect`).

## Binding table — external reads

Integrations per `notes/architecture.md#Integration-Points`; tool names enumerated live at the binding test gates, not guessed.

| Logical capability | Scope | Cowork tool + read-call shape (verbatim) | Consumed by |
| --- | --- | --- | --- |
| `calendar.list_events_since(ts)` — `ts` is an ISO-8601 timestamp | read | `gws calendar events list --params '{"calendarId":"primary","timeMin":"<ts>","singleEvents":true,"orderBy":"startTime"}'` — Google Calendar via the `gws` Google Workspace CLI (OAuth read scope) | `skills/pipeline/discover-events.md` |
| `calendar.availability(attendees, window)` — `attendees` = the rep + the named stakeholders; `window` = start/end ISO 8601, resolved in-skill; bounded to one query per draft. Honest degradation: unreadable attendee → rep-only slots phrased as offers to confirm; capability unavailable → the meeting ask carries no concrete times | read | **Primary:** `gws calendar freebusy query --params '{"timeMin":"<window start>","timeMax":"<window end>","items":[{"id":"<attendee email>"}, ...]}'` — busy blocks per attendee; open slots derived in-skill (pure date math, run `timezone`). **Fallback** (if freebusy is not exposed — verify at the next test gate): rep-only open slots derived in-skill from the `gws calendar events list` read over the window. | `skills/handlers/draft-followup.md` (AVAILABILITY) |
| `transcript.get(call_ref)` — provider `granola` | read | native Granola MCP connector — `get_meeting_transcript`; correlate `call_ref` → meeting via `list_meetings` / `query_granola_meetings` / `get_meetings` | `skills/pipeline/fetch-transcript.md` |
| `transcript.get(call_ref)` — provider `zoom` | read | native Zoom MCP connector — `get_meeting_assets(meeting_id)` to select the transcript asset, then `get_recording_resource(asset_ref)` for the body; correlate via `search_meetings(query=<title or attendee>)` / `search_zoom` / `recordings_list(date_window)` | `skills/pipeline/fetch-transcript.md` |
| `transcript.get(call_ref)` — provider `gong` | read | native Gong MCP connector — search/list call to correlate, then transcript-fetch call for the body. *Not currently invoked — the row activates when the host exposes the connector.* | `skills/pipeline/fetch-transcript.md` |
| `content.search(query)` — returns opaque `ref`s | read | `gws drive files list --params '{"q":"<query>","fields":"files(id,name,mimeType)"}'` | `skills/handlers/draft-followup.md`, `skills/setup-unbound.md` (Drive intake) |
| `content.get(ref)` — resolves a `ref` to its content | read | `gws drive files get --params '{"fileId":"<ref>","fields":"id,name,mimeType"}'` (Drive `files export`/media for the body) | `skills/handlers/draft-followup.md`, `skills/setup-unbound.md` (Drive intake + asset-link verification) |
| `web.fetch(url)` — resolves a public web page URL to its readable content | read | Concrete Cowork web-fetch tool **enumerated live at the setup binding test gate** (per the indirection rule — never guessed in advance). **Optional-degraded:** capability unavailable ⇒ the website intake path is unavailable, stated to the user; setup proceeds via chat files, Drive, or the interview. | `skills/setup-unbound.md` (website intake) |
| `email.list_unanswered_threads(ts)` — all thread fields carried verbatim: `thread_ref` (opaque correlation key), `subject`, `participants[]` (`{ name?, email? }`), `last_message_at` (ISO 8601 with offset; compared in the run's `timezone`, never reformatted); `latest_external_message_body` is inline (earlier messages not loaded) | read | **Primary:** `gws gmail threads list --params '{"q":"in:inbox -in:sent -category:promotions -category:social -category:updates -in:spam -in:trash after:<ts_unix>","labelIds":["INBOX"]}'`; thread bodies via `gws gmail threads get`. The `q` parameter is the **hard pre-filter**, owned here, not by the skill: INBOX-only; exclude promotions/social/updates/spam/trash; `-in:sent` keeps only threads where the rep has not replied last. **Fallback:** native Gmail MCP connector — `mcp__claude_ai_Gmail__search_threads` (same `q`) + `mcp__claude_ai_Gmail__get_thread`. | `skills/pipeline/discover-events.md` |
| `email.get_thread(thread_ref)` — get-by-ref: resolve ONE stored `thread_ref` to its thread, for evidence recovery on a later run. Same thread shape as the list capability; **no `q`, no window, no search** — the ref is the whole query, so recovery does not depend on the discovery window | read | **Primary:** `gws gmail threads get --params '{"id":"<thread_ref>"}'` — the same read the list capability already uses for thread bodies, addressed by ref alone. **Fallback:** native Gmail MCP connector — `mcp__claude_ai_Gmail__get_thread`. A ref that no longer resolves (thread deleted, moved out of the account, or otherwise purged) returns `missing` — never a nearest-match thread, never a fabricated body. | `skills/pipeline/fetch-transcript.md` (evidence recovery) |

> **Gmail test gate.** Which Gmail surface resolves in Cowork is determined live at the discovery test gate.
> **TO BE FILLED IN AT TEST GATE:** the verified tool (primary or fallback), one-line live-call evidence, and any <!-- lint-allow: pending live test-gate resolution -->
> required `q` deviation; until then: primary preferred, fallback documented, resolution pending.

## Binding table — render/capture surfaces

All eight resolve interactively to `mcp__visualize__show_widget` rendering the pinned template — layout minutiae live in the template, never in prose; surface choice per the resolution rule below.

| Logical capability | Scope | Interactive surface (pinned template) | Fallback | Consumed by |
| --- | --- | --- | --- | --- |
| `render.tasks(task_view)` | render, no capture | card stack, one card per task — `runtime/templates/task-plan-widget.html` | plain Markdown checklist in chat | `skills/pipeline/work-account.md` (re-render after SET-STATUS / APPLY-EDIT), `skills/standalone/collect-tasks.md` (roundup) |
| `review.collect(checkpoint_view)` | render/capture (local verdicts only) | **batch:** triage card stack with per-card controls, one submit — `runtime/templates/batch-triage-widget.html`; **single-item:** checkpoint card, one item per call — `runtime/templates/checkpoint-widget.html` | in-chat `accept \| edit \| reject` prompt per item | `skills/run-unbound.md` (Step 3.5 batch triage + Step 3.5 material-edit re-confirm + Step 5 close-out open questions) |
| `render.slate(slate_view)` | render, no capture | card grid, one card per derived pending-event group — `runtime/templates/slate-widget.html` | plain annotated slate lines | `skills/pipeline/build-slate.md` Step 4 (via `run-unbound` Steps 2–3) |
| `render.email_draft(draft_view)` | render/capture (the draft's own verdict) | mail-client preview carrying an Accept / Reject / free-text-edit verdict footer — `runtime/templates/email-draft-widget.html` | cited filename + draft body in chat, with the same three verdicts invited in chat | `skills/run-unbound.md` (Step 5 combined output gate) |
| `render.crm_update(crm_view)` | render, no capture | informational CRM card — `runtime/templates/crm-update-widget.html` | plain in-chat "CRM Updates (simulated)" Markdown section | `skills/pipeline/write-crm.md` (APPLY — simulate branch) |
| `render.connections(connections_view)` | render, no capture | capability status board capped by the readiness banner — `runtime/templates/connections-widget.html` | plain Markdown capability table + verdict line in chat | `skills/standalone/connect-tools.md` (both entries) |
| `render.setup_progress(progress_view)` | render, no capture | section checklist card — `runtime/templates/setup-progress-widget.html` | plain Markdown section-status list in chat | `skills/setup-unbound.md` (progress + resume + audit views) |
| `render.context_preview(preview_view)` | render, no capture | formatted artifact preview (positioning block / stage-ladder pipeline / asset table) — `runtime/templates/context-preview-widget.html` | plain Markdown artifact section in chat | `skills/setup-unbound.md` (section-loop previews) |

## API contract — logical capability signatures (stable across runtimes)

Per `notes/architecture.md#API-Contracts`; only the binding tables change per runtime. Render view shapes live in their capability sections below.

```
calendar.list_events_since(ts)  -> [event]               # read
calendar.availability(attendees, window) -> [open_slot]  # read; open_slot = { start, end } (ISO 8601 with offset, in the run's timezone); an attendee whose free/busy is unreadable is reported unreadable, never guessed
transcript.get(call_ref)        -> { text, provider } | missing  # read; binding fans out across all configured providers in parallel, returns the best confident match tagged with its source `provider`; `missing` => never silently drop (Pattern 2). Default `provider_priority: [granola, gong, zoom]`.
content.search(query)           -> [ref]                  # read
content.get(ref)                -> content                # read
web.fetch(url)                  -> page_content | unavailable  # read; optional-degraded — unavailable ⇒ website intake unavailable (stated), setup proceeds via files/Drive/interview
email.list_unanswered_threads(ts) -> [thread]            # read; threads where the rep has not replied last
                                                          # thread = { thread_ref, subject, participants[],
                                                          #            last_message_at (ISO 8601 with offset),
                                                          #            latest_external_message_body }
email.get_thread(thread_ref)    -> thread | missing       # read; get-by-ref, same thread shape, no window and no search — the
                                                          # email counterpart of transcript.get for evidence recovery; a ref that
                                                          # no longer resolves => missing (Pattern 2 — surfaced, never fabricated)
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

## Resolution rule — all render capabilities

Interactive mode is used **only** on positive confirmation that `mcp__visualize__show_widget` is present in the runtime's
tool list; when the surface is absent or cannot be confirmed (Claude Code, capability unknown), resolve to the
capability's documented fallback — **never assume rich UI**.

**Resolve once per session, then reuse.** That confirmation is performed **once**, at the session's first render/capture
beat, and the answer it produced is reused at every later `render.*` and `review.collect` call site. A runtime's tool
inventory cannot change mid-session, so re-confirming at each of the five-to-eight sites a single run reaches
(`render.slate`, the Step 3.5 batch `review.collect`, a material-edit re-confirm, `render.email_draft`, the close-out
open-questions `review.collect`, `render.crm_update`) is strictly wasted work — it cannot produce a different answer.

Caching the resolution never upgrades it. A surface that was absent or could not be confirmed caches the **fallback**,
and every site then uses that fallback: "could not confirm" never becomes an assumed rich UI at a later beat, which is
the same rule as above, stated for the cached case. Both modes carry the same content — no field dropped or invented on
either surface (ADR-1); an `inferred:` evidence/basis marker renders as-is, never dressed as a citation. Widget
mechanics (`read_me`/`show_widget` protocol, failure handling, fragment constraints, sendPrompt grammar, ADR-9 click
semantics) live in `runtime/adapters/cowork.md`.

## render.tasks

`task_view` = canonical tasks (`id`/`title`/`priority`/`type`/`status`/`evidence`), optionally grouped by item
`namespace/slug`. Presentation only: the cards carry **no checkbox and no buttons** — verdicts happen at the Step 3.5
`review.collect` triage; the card's evidence line shows the cited quote or the `inferred:` marker; the roundup
(`collect-tasks`) adds a status pill and groups cards under `namespace/slug` headers. The former
checkbox-capture-on-return binding is **retired**; `render.tasks` conveys nothing back and introduces no writer — task
status changes are explicit chat asks applied via SET-STATUS, the single status write authority. Display labels are
presentation-only (`not-done → "open"`, `done → "done"`, `deferred → "deferred"`; Markdown fallback: `- [x]` done,
`- [ ]` otherwise); the persisted enum `not-done | done | deferred` is never changed by rendering.

## review.collect

`checkpoint_view = { items[], open_questions[] }`; each `item = { task_id, title, rationale, evidence, context?, kind:
"task" | "context_section" | "binding_change", body? }` — `context` is the task's typed
execution-context block on `kind: "task"` items. The produced email draft is **not** an item kind here: it carries its
own verdict on its own surface (see `## render.email_draft`). Returns
`verdicts = { item_verdicts[], open_answers[] }`; `item_verdict = { task_id, verdict ∈ {accept|edit|reject}, note }`;
`open_answer = { question, answer }`.

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
`Evidence · call (<call_type>)`); the verdict-prompt strings are the adapter's sendPrompt grammar. The batch card carries
P# badge, type pill, title, rationale, and one source-prefixed evidence line and **omits the typed `context` block**
(progressive disclosure — depth belongs to the output gate); the single-item card keeps its two-column context grid, whose
labels vary by task type.

Verdict mapping: Accept → `accept`; Reject → `reject`; a free-text edit → `edit` with the text captured **verbatim** as
`note`. **No answer for an item → no verdict for that item** (silence is not a verdict); hand-typed equivalents map
identically; ambiguous free text that cannot map to the enum → ask, never an out-of-enum write. Verdicts route through
the existing write authorities — no new writer: one `capture-feedback(namespace, slug, task_id, verdict, note)` line per
verdict to `state/feedback-log.jsonl`; a **task** `edit` is applied via work-account's APPLY-EDIT (an **output** `edit`
is applied by the artifact's own handler — see `## render.email_draft`); verdicts never touch task `status`
(SET-STATUS's domain). `open_questions[]`
are **never widget-rendered** — they remain in-chat free text; `open_answers[]` are surfaced only — echoed in chat,
nothing written (future persistence is ENRICH's, never the checkpoint's).

Setup-time item kinds (outside the run loop): `context_section` — the item is one previewed context section, its
`task_id` slot carrying the section id (`process | messaging | assets | state`); consumed by `skills/setup-unbound.md`
(section verdicts, state-init confirm, refresh proposals). `binding_change` — the item is one proposed row edit to this
file; consumed by `skills/standalone/connect-tools.md`. One item per call, never batched, and the
`accept | edit | reject` enum are unchanged. **Routing outside the run loop:** accept ⇒ the invoking skill performs its
local file write; edit ⇒ the note is applied to the draft/proposal and re-presented; reject ⇒ the section is re-entered
/ the proposal dropped. **No `feedback-log.jsonl` line is written** — `capture-feedback` remains exclusively the run
loop's prioritization instrument; silence is still not a verdict, and ambiguous free text still maps to ask, never an
out-of-enum write.

## render.slate

`slate_view` = the annotated per-account groups `build-slate` Step 4 **derives** by grouping the run-state `events` with
`processing_status: pending` by `(namespace, slug)` (name, namespace, stage-if-known, call signal, email signal,
evidence flag, plus the display strings its label-derivation rules produce — subtitle and recency labels; nothing is
re-derived at render time). One card per group, exactly as before — the derivation changed, the card contract did not.
Pure render; selection stays rep-owned. Pill text rules: call
pill `"Call · <recency>"`, appending `" · no recording"` **verbatim** when that call event's `evidence_status` is `missing`,
and appending **nothing** when it is `unknown` — no clause, no placeholder, no dangling `·`, because nothing has been
fetched yet and an absent fact yields an absent label; a newly-discovered call is `unknown`, so the clause now fires only
for a call an earlier run resolved. `unknown` is never rendered as `present` or as `missing`.
Email pill `"<N> unanswered email<s> · <recency>"`; both-signal groups show both pills, call pill first; an absent date
omits the recency clause entirely — no dangling separator. The muted subtitle reads
`<Humanized stage> · <Humanized topic>`, or whichever single part is known, or the humanized namespace singular
(`Account` / `Project`) when neither is. The full-width
**`Work <Name>`** button (name with `&`/punctuation flattened to words) is the selection utterance: the click writes
nothing and sends that text as the rep's selection turn, matched exactly as if typed (case-insensitive; ambiguity →
ask) — `render.slate` causes no write of any kind. An **empty slate renders no widget** (the existing "empty slate" chat
line stands); the `dropped` set is **never** widget-rendered (inspect-on-request stays chat-based).

## render.email_draft

`draft_view = { to[], subject, body, filename }`, read from the draft file `draft-followup` already wrote under the
item's `drafts/` — nothing is regenerated or altered at render time. **Render/capture:** the preview carries a
**verdict footer** — Accept / Reject buttons plus a free-text edit input and Submit — and returns the draft's
`item_verdict = { task_id, verdict ∈ {accept|edit|reject}, note }`, where `task_id` is the draft's `source_task`. The
draft and the decision on it are **one surface**; no separate checkpoint card follows it, and the verdict strings are
the **existing** per-item sendPrompt grammar — no second grammar exists. The amber `draft · not sent` pill states the
boundary the footer does not move: nothing is sent, queued, or renamed. The draft's filename is cited in chat
alongside the widget.

An **`edit` verdict is applied**, not merely recorded: `draft-followup`'s `apply-draft-edit(namespace, slug,
source_task, note)` rewrites the draft file — bounded to `to[]`, `subject`, `body` — **first**, appends exactly one
`edit` line via `capture-feedback` **only** on success, and re-renders through this capability so a fresh verdict is
collected. The cycle repeats until accept or abandon; one log line per cycle, append-only, and it is rep-bounded — each
cycle takes a rep turn. Silence after a re-render writes nothing and leaves the draft at its last applied state. This
capability adds **no** writer: the draft file is one `draft-followup` already owned.

## render.crm_update

`crm_view` = the in-memory `crm_update` object `work-account` Step 6.5 handed back (`current_stage`,
`stage_recommendation { recommendation, to_stage, criteria[], unmet[], reason }`, the verbatim-carried `next_step`,
`product_gaps[]`) plus the persisted `drafts/YYYY-MM-DD-crm-update.md` `filename`; nothing is re-evaluated at render
time. **Informational only:** zero affordances, returns nothing; no `review.collect` call follows, no `capture-feedback`
line is written, and silence has no meaning here. Card text rules: exactly one recommendation pill —
`advance to <stage>` / `no change` / `not applicable — <reason>`; a met exit criterion carries its source-prefixed
citation, an unmet one reads `no evidence this run`, and the criteria block is **omitted entirely on `not-applicable`**
(no criteria were evaluated); the carried `next_step` renders in one line (or its explicit no-next-step reason); one
cited bullet per product gap, or the honest `none raised this run` line when empty. The persisted filename is cited in
chat with the explicit statement that **nothing was written to any external system**; the stage recommendation stays
advisory — ENRICH remains the sole stage writer; the rep applies it to their real CRM if they agree.

## render.connections

`connections_view = { capabilities[]: { capability, status: connected|missing|degraded, tool?, consequence },
verdict: { ready: true } | { ready: false, exceptions[]: { what, unlocks } } }` — the capability status board
`skills/standalone/connect-tools.md` assembles from its introspection pass (both entries); nothing is
re-evaluated at render time. `tool` is a concrete name arriving **from the live environment** (environment →
conversation → this file — never from skill prose, ADR-6); `consequence` is the run-time cost of a gap in the
honest-degradation voice (e.g. no transcript source ⇒ calls worked `transcript: missing`). Board text rules: one
status row per capability — the capability name, its status pill (`connected | missing | degraded`), the serving
`tool` when bound, and the muted `consequence` line on `missing`/`degraded` rows; the `verdict` banner closes
the board — `READY TO RUN`, or `READY EXCEPT` with one what/unlocks line per exception. **Render-only, conveys
nothing back:** zero affordances, no verdict, no write — binding-change verdicts flow through `review.collect`
items of kind `binding_change` (see `## review.collect`), never through this surface.

## render.setup_progress

`progress_view = { mode: first-run|refresh|resume, sections[]: { id: process|messaging|assets|state,
status: done|active|pending | proposed-changes(n), coverage_note? } }` — the section checklist
`skills/setup-unbound.md` renders at its opening, after each section, on resume, and as the refresh audit
view; nothing is re-evaluated at render time. The section-id enum is fixed in D9 order
(`process | messaging | assets | state`) — the same enum `review.collect`'s `context_section` `task_id`
slot carries. `proposed-changes(n)` is the refresh/audit status variant, consumed by Epic setup-3 with
**no shape change**; `coverage_note` is an optional muted annotation (e.g. "mostly covered by deck").
Card text rules: one mode line (`first-run | refresh | resume`) at the top; one row per section, in D9
order, carrying the section name, its status pill (`done | active | pending | proposed-changes(n)`), and
the muted coverage note when present. **Render-only, conveys nothing back:** zero affordances, no
verdict, no write — section verdicts flow through `review.collect` items of kind `context_section` (see
`## review.collect`), never through this surface.

## render.context_preview

`preview_view = { section_id, drafted_content, provenance[]: { block_ref, label }, gaps[] }` — the
drafted artifact `skills/setup-unbound.md` previews in its section loop, before each verdict; nothing is
regenerated or altered at render time. `drafted_content` is the artifact **shaped like itself** — the
thing being built, not a transcript of chat: a positioning block for `messaging`, the stage-ladder
pipeline for `process`, the six-column asset table for `assets`. Provenance labels
(`Evidence · <source> <locator>` / `Answer · rep`) are a **preview overlay only, never written to
files** — the accepted artifact strips them; gaps render in the D13 blockquote voice and are the only
overlay content that persists (as D13 blockquotes in the written file). **Render-only, conveys nothing
back:** zero affordances, no verdict, no write — verdicts never flow through this surface; they belong
to `review.collect` items of kind `context_section` (see `## review.collect`).

## transcript.get (multi-source)

- **Provider set.** One binding row per provider. The current set is `{ granola, zoom, gong }` — `granola` and `zoom`
  are bound and invoked; `gong` is authored activation-ready and activates as a single-row edit when the host exposes
  the connector. Adding a future provider is the same single-row edit — the skill never changes.
- **Match policy.** For each `call_ref`: (a) issue every configured provider's correlation + transcript-fetch sequence
  (parallel where supported); (b) keep **confident matches only** — fuzzy/uncertain candidates and transcripts returned
  without a confidence signal are discarded (Pattern 2 — never mis-attribute); (c) rank by native confidence,
  descending; (d) tie-break by `provider_priority` (default in the API contract; the rep edits that one line to change
  preference); (e) return `{ text: <verbatim transcript>, provider: <winning key> }`, or **`missing`** when none
  is confident — the consuming skill marks the call `transcript: missing`, surfaces it, never fabricates.
- **Two concurrency axes — do not conflate them.** *Within* one `call_ref` the fan-out is **across providers**: that is
  the "parallel where supported" clause in the match policy above, it is bounded by the size of the provider set, and it
  is entirely this file's concern. *Across* the independent events of one selected item the fan-out is **across
  `call_ref`s**, it belongs to `skills/pipeline/fetch-transcript.md`, and that skill states its own numeric bound. The
  two nest rather than compete — a bounded set of events in flight, each issuing its own provider sequence — and neither
  bound is derived from, nor a restatement of, the other. A change to the provider set moves only the first; a change to
  the recovery skill's bound moves only the second.
- **`provider` carried verbatim.** A short kebab-case key from the provider rows; never `null` on present, never present
  on `missing`; carried verbatim onto every `transcript: present` record (no rewriting, normalization, truncation, or
  case round-trip); downstream may surface or ignore it — carrying is mandatory.
- **ADR-6 grep gate (load-bearing).** `skills/pipeline/fetch-transcript.md` and its mirror MUST contain zero occurrences
  of `granola`, `zoom`, `gong`, or any concrete provider tool name.
- **Edge cases.** Identical transcripts from two providers → priority picks one, the other discarded silently; confident
  beats fuzzy; all fuzzy/missing → `missing`; a transient provider error → `not_found` for that `call_ref`, others
  still evaluated (Pattern 2).
- **Write boundary.** Every provider is read-scope only; Zoom's `create_new_file_with_markdown` is a write tool and is
  **NOT bound** (ADR-4).

## Binding table — declared future write gate (unbound)

> **Declared-but-unbound.** The one named future write capability, carried here with its documented simulate fallback so
> the boundary is explicit. It is **NOT BOUND** to any concrete tool in any runtime and has no `runtime/adapters/cowork.md`
> row — this row **requests and configures no write scope** (ADR-4; the external write boundary stays closed).
> `connect-tools` derives it like any other binding row and reports it `missing`/`degraded` with the simulate consequence.

| Logical capability | Scope | Status / binding | Fallback | Consumed by |
| --- | --- | --- | --- | --- |
| `crm.write(crm_update)` — apply the field-level `crm_update` to the CRM (Growth / Epic G, FR28–FR34) | write (future) | **NOT BOUND** in any runtime — no concrete tool, no `runtime/adapters/cowork.md` row (write boundary closed, ADR-4) | **simulate** — persist the item's `drafts/YYYY-MM-DD-crm-update.md` + `render.crm_update` (informational); nothing written externally | `skills/pipeline/write-crm.md` (RESOLVE → APPLY — simulate branch) |

Binding `crm.write` is **deferred pending an ADR-4 amendment** (Epic G activation); until then `write-crm`'s RESOLVE
always selects the simulate fallback (positive-confirmation-or-fallback, per the resolution rule above). `crm.read` /
`crm.write_draft` remain in **Out of scope** below — `crm.write` is the *named, still-closed* gate, not an opened write
scope.

## Out of scope (do NOT add here)

- Any **external write-scoped** capability: `email.queue_draft`, `gmail.send`, `gmail.modify`, `gmail.label`,
  `crm.read`, `crm.write_draft` (Growth FR28–FR34). Gmail is list-and-read only in the discovery window — never send,
  reply, draft-into-Gmail, label, archive, or modify.
- Bindings/adapters for other runtimes (ChatGPT, Copilot) — deferred, per the indirection rule.
