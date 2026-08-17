# Tool Bindings — Claude Cowork

> **What this file is.** The single source of truth mapping each **logical capability** a skill may call to the **concrete
> runtime tool** that satisfies it on **Claude Cowork** — with `resources/tool-bindings.md`, the only runtime-specific surface
> (ADR-6 / Pattern 4).

## The indirection rule (ADR-6)

- **Core** skills under `skills/` reference **only logical capability names**; they never name a concrete runtime tool. For
  core, concrete tool names live only in this file and `resources/tool-bindings.md`. A client-overlay handler may instead
  self-declare in its own `## Capabilities` table (`task-registry.md` → "Client overlays") — the one surface outside this rule.
- Porting = one bindings entry/file + one adapter under `runtime/adapters/`; nothing under `skills/` changes (Pattern 4).
- Sibling authorities: `runtime/chatgpt/tool-bindings.md` (ChatGPT Work) and `runtime/demo/tool-bindings.md`
  (fixture-backed demo); every binding below covers the **Cowork** surface plus its documented fallback only.

## Security posture (ADR-4)

Every **read** binding in this file is **read-scope only**, and external **writes are never implicit**: a write can occur
only through a capability this file *explicitly declares* with a write scope, and only when all four of ADR-4's amended
conditions hold — the capability is **positively confirmed bound**, the rep **approves the exact payload in-session, once
per write**, the mapping is **production-eligible** on one of the operation contract's two paths — provider-proven
replay, or caller-owned ledger-plus-read-back recovery — so one approved update lands as one
update and not two — and anything short of that **degrades honestly** to the simulate path. No capability acquires a write scope by turning up in a
runtime's tool list, and where none is declared or bound this file requests and configures no write scope at all (growth
capabilities: "Out of scope").
The `render.*` /
`review.collect` capabilities are **local render/capture surfaces, not external reads or writes**: none introduces a new
writer or write scope; the only writes they can lead to are the existing local authorities in
`skills/pipeline/work-account.md` — SET-STATUS, `capture-feedback`, and APPLY-EDIT — plus, for the setup-time
`review.collect` item kinds, the invoking skill's local file write (see `## review.collect`).

## Binding table — external reads

Integrations per `notes/architecture.md#Integration-Points`; tool names are recorded exactly as enumerated live at the binding test gates — including bare names — never guessed or re-prefixed.

| Logical capability | Scope | Cowork tool + read-call shape (verbatim) | Consumed by |
| --- | --- | --- | --- |
| `calendar.list_events_since(ts)` — `ts` is an ISO-8601 timestamp | read | native Google Calendar MCP connector — `mcp__Google_Calendar__list_events` with `startTime = <ts>` and `orderBy: startTime` (primary calendar; connector OAuth read scope) | `skills/pipeline/discover-events.md` |
| `calendar.availability(attendees, window)` — `attendees` = the rep + the named stakeholders; `window` = start/end ISO 8601, resolved in-skill; bounded to one query per draft. Honest degradation: unreadable attendee → rep-only slots phrased as offers to confirm; capability unavailable → the meeting ask carries no concrete times | read | **Primary:** native Google Calendar MCP connector — `mcp__Google_Calendar__suggest_time` with `attendeeEmails = <attendees>` and `startTime`/`endTime` = the window — free slots across all named attendees, returned directly (run `timezone` passed through). **Fallback** (if the suggest tool is unavailable): rep-only open slots derived in-skill from the `mcp__Google_Calendar__list_events` read over the window. | `skills/handlers/draft-followup.md` (AVAILABILITY) |
| `transcript.get(call_ref)` — provider `granola` | read | native Granola MCP connector — `get_meeting_transcript`; correlate `call_ref` → meeting via `list_meetings` / `query_granola_meetings` / `get_meetings` | `skills/pipeline/fetch-transcript.md` |
| `transcript.get(call_ref)` — provider `zoom` | read | native Zoom MCP connector — `get_meeting_assets(meeting_id)` to select the transcript asset, then `get_recording_resource(asset_ref)` for the body; correlate via `search_meetings(query=<title or attendee>)` / `search_zoom` / `recordings_list(date_window)` | `skills/pipeline/fetch-transcript.md` |
| `transcript.get(call_ref)` — provider `gong` | read | native Gong MCP connector — search/list call to correlate, then transcript-fetch call for the body. *Not currently invoked — the row activates when the host exposes the connector.* | `skills/pipeline/fetch-transcript.md` |
| `content.search(query)` — returns opaque `ref`s | read | native Google Drive MCP connector — `mcp__Google_Drive__search_files` (structured query built from `query`; returns matching files' id, name, MIME type) | `skills/handlers/draft-followup.md`, `skills/setup-unbound.md` (Drive intake) |
| `content.get(ref)` — resolves a `ref` to its content | read | native Google Drive MCP connector — `mcp__Google_Drive__get_file_metadata` for id/name/MIME type, then `mcp__Google_Drive__read_file_content` for the body | `skills/handlers/draft-followup.md`, `skills/setup-unbound.md` (Drive intake + asset-link verification) |
| `web.fetch(url)` — resolves a public web page URL to its readable content | read | Cowork runtime tool — `WebFetch`. **Optional-degraded:** capability unavailable ⇒ the website intake path is unavailable, stated to the user; setup proceeds via chat files, Drive, or the interview. | `skills/setup-unbound.md` (website intake) |
| `email.list_unanswered_threads(ts)` — all thread fields carried verbatim: `thread_ref` (opaque correlation key), `subject`, `participants[]` (`{ name?, email? }`), `last_message_at` (ISO 8601 with offset; compared in the run's `timezone`, never reformatted); `latest_external_message_body` is inline (earlier messages not loaded) | read | native Gmail MCP connector — `mcp__Gmail__search_threads` with `q = "in:inbox -in:sent -category:promotions -category:social -category:updates -in:spam -in:trash after:<ts_unix>"`; thread bodies via `mcp__Gmail__get_thread`. The `q` parameter is the **hard pre-filter**, owned here, not by the skill: INBOX-only; exclude promotions/social/updates/spam/trash; `-in:sent` keeps only threads where the rep has not replied last. | `skills/pipeline/discover-events.md` |
| `email.list_sent_threads(ts, limit)` — the rep's **own** outbound messages, read for voice extraction only. Each carries `message_ref` (opaque), `subject`, `recipients[]` (`{ name?, email? }`), `sent_at` (ISO 8601 with offset) and `body`; `limit` caps the read at the most recent N (default 25), and `ts` is its lower bound | read | native Gmail MCP connector — `mcp__Gmail__search_threads` with `q = "in:sent -in:chats -in:draft after:<ts_unix>"`; bodies via `mcp__Gmail__get_thread`. The `q` parameter is the **hard pre-filter**, owned here, not by the skill: SENT-only, chats and drafts excluded. **No new authorization:** the read scope the discovery binding already uses covers SENT — this row adds a capability, not a scope. **Optional-degraded:** capability unavailable ⇒ the sent-mail voice path is unavailable, stated to the user; setup proceeds from the writing samples the rep provides and the voice interview. | `skills/setup-unbound.md` (voice intake) |
| `email.get_thread(thread_ref)` — get-by-ref: resolve ONE stored `thread_ref` to its thread, for evidence recovery on a later run. Same thread shape as the list capability; **no `q`, no window, no search** — the ref is the whole query, so recovery does not depend on the discovery window | read | native Gmail MCP connector — `mcp__Gmail__get_thread` with `threadId = <thread_ref>` — the same read the list capability already uses for thread bodies, addressed by ref alone. A ref that no longer resolves (thread deleted, moved out of the account, or otherwise purged) returns `missing` — never a nearest-match thread, never a fabricated body. | `skills/pipeline/fetch-transcript.md` (evidence recovery) |

> **Gmail test gate — verified 2026-08-15.** Cowork exposes the primary native surface:
> `mcp__Gmail__search_threads` plus `mcp__Gmail__get_thread`. It serves both list capabilities and
> get-by-ref under the same read scope; the two binding-owned `q` pre-filters above require no deviation.

## Binding table — render/capture surfaces

All rows resolve interactively to `mcp__visualize__show_widget` rendering the pinned template — layout minutiae live in the template, never in prose; surface choice per the resolution rule below.

| Logical capability | Scope | Interactive surface (pinned template) | Fallback | Consumed by |
| --- | --- | --- | --- | --- |
| `render.tasks(task_view)` | render, no capture | card stack, one card per task — `resources/templates/task-plan-widget.html` | plain Markdown checklist in chat | `skills/pipeline/work-account.md` (re-render after SET-STATUS / APPLY-EDIT), `skills/standalone/collect-tasks.md` (roundup) |
| `review.collect(checkpoint_view)` | render/capture (local verdicts only) | **batch:** triage card stack with per-card controls, one submit — `resources/templates/batch-triage-widget.html`; **single-item:** checkpoint card, one item per call — `resources/templates/checkpoint-widget.html` | in-chat `accept \| edit \| reject` prompt per item | `skills/run-unbound.md` (Step 3.5 batch triage + Step 3.5 material-edit re-confirm + Step 5 close-out open questions + qualification gaps) |
| `render.slate(slate_view)` | render, no capture | card grid, one card per derived pending-event group — `resources/templates/slate-widget.html` | plain annotated slate lines | `skills/pipeline/build-slate.md` Step 4 (via `run-unbound` Steps 2–3) |
| `render.email_draft(draft_view)` | render/capture (the draft's own verdict) | mail-client preview carrying an Accept / Reject / free-text-edit verdict footer — `resources/templates/email-draft-widget.html` | cited filename + draft body in chat, with the same three verdicts invited in chat | `skills/handlers/draft-followup.md`, at the EXECUTE TASKS artifact-verdict gate (`triage-and-execute.md` Step 4) |
| `render.artifact(artifact_view)` | render/capture (the artifact's own verdict) | generic artifact preview carrying an Accept / Reject / free-text-edit verdict footer — `resources/templates/artifact-widget.html` | cited filename + `body_blocks[]` content in chat, with the same three verdicts invited in chat | any `execute` handler per `task-registry.md` Part B's Output-edit obligation (default render capability) |
| `render.crm_update(crm_view)` | render, no capture | informational CRM card — `resources/templates/crm-update-widget.html` | plain in-chat "CRM Updates (simulated)" Markdown section | `skills/pipeline/write-crm.md` (APPLY) |
| `render.connections(connections_view)` | render, no capture | capability status board capped by the readiness banner — `resources/templates/connections-widget.html` | plain Markdown capability table + verdict line in chat | `skills/standalone/connect-tools.md` (both entries) |
| `render.setup_progress(progress_view)` | render, no capture | section checklist card — `resources/templates/setup-progress-widget.html` | plain Markdown section-status list in chat | `skills/setup-unbound.md` (progress + resume + audit views) |
| `render.context_preview(preview_view)` | render, no capture | formatted artifact preview (positioning block / stage-ladder pipeline / asset table) — `resources/templates/context-preview-widget.html` | plain Markdown artifact section in chat | `skills/setup-unbound.md` (section-loop previews) |
| `render.source_intake(intake_view)` | render, no capture | source-catalog checklist card — `resources/templates/source-intake-widget.html` | plain Markdown item-status list in chat | `skills/setup-unbound.md` (step-2 intake, re-rendered after each answer) |

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
email.list_sent_threads(ts, limit) -> [sent_message] | unavailable  # read; optional-degraded — the rep's own outbound mail, read at
                                                          # setup for voice extraction only, capped at the most recent `limit`
                                                          # (default 25); unavailable ⇒ sent-mail voice path unavailable (stated),
                                                          # setup proceeds from provided samples + the voice interview
                                                          # sent_message = { message_ref, subject, recipients[],
                                                          #                  sent_at (ISO 8601 with offset), body }
email.get_thread(thread_ref)    -> thread | missing       # read; get-by-ref, same thread shape, no window and no search — the
                                                          # email counterpart of transcript.get for evidence recovery; a ref that
                                                          # no longer resolves => missing (Pattern 2 — surfaced, never fabricated)
render.tasks(task_view)         -> interactive_checklist | markdown_checklist   # render, no capture
review.collect(checkpoint_view) -> verdicts                                     # render/capture; verdicts route to capture-feedback
render.slate(slate_view)        -> slate_cards | annotated_lines                 # render; interactive card grid, fallback = plain annotated slate lines
render.email_draft(draft_view)  -> { preview, item_verdict }                     # render/capture; interactive mail-client preview + verdict footer, fallback = cited filename + body in chat with the verdict invited in chat
render.artifact(artifact_view)  -> { preview, item_verdict }                     # render/capture; generic artifact preview + verdict footer, fallback = cited filename + body_blocks[] in chat with the verdict invited in chat
render.crm_update(crm_view)     -> crm_card | markdown_block                     # render; informational CRM-update card, fallback = plain in-chat "CRM Updates (simulated)" Markdown section
render.connections(connections_view) -> connections_board | markdown_table       # render, no capture
render.setup_progress(progress_view) -> progress_card | markdown_list            # render, no capture
render.context_preview(preview_view) -> artifact_preview | markdown_section      # render, no capture
render.source_intake(intake_view)   -> intake_card | markdown_list               # render, no capture
```


## Resolution rule — all render capabilities

Interactive mode is used **only** on positive confirmation that `mcp__visualize__show_widget` is present in the runtime's
tool list; when the surface is absent or cannot be confirmed (Claude Code, capability unknown), resolve to the
capability's documented fallback — **never assume rich UI**.

**Resolve once per session, then reuse.** That confirmation is performed **once**, at the session's first render/capture
beat, and its answer is reused at every later `render.*` and `review.collect` call site — a runtime's tool inventory
cannot change mid-session. Caching the resolution never upgrades it: a surface that was absent or could not be
confirmed caches the **fallback**, and "could not confirm" never becomes an assumed rich UI at a later beat. Both modes
carry the same content — no field dropped or invented on either surface (ADR-1); an `inferred:` evidence/basis marker
renders as-is, never dressed as a citation. Widget mechanics (`read_me`/`show_widget` protocol, failure handling,
fragment constraints, sendPrompt grammar, ADR-9 click semantics) live in `resources/tool-bindings.md`.

## render.tasks

`task_view` = canonical tasks (`id`/`title`/`priority`/`type`/`status`/`evidence`), optionally grouped by item
`namespace/slug`. Presentation only: the cards carry **no checkbox and no buttons** — verdicts happen at the Step 3.5
`review.collect` triage; the card's evidence line shows the cited quote or the `inferred:` marker; the roundup
(`collect-tasks`) adds a status pill and groups cards under `namespace/slug` headers. `render.tasks` conveys nothing
back and introduces no writer — task status changes are explicit chat asks applied via SET-STATUS, the single status write authority. Display labels are
presentation-only (`not-done → "open"`, `done → "done"`, `deferred → "deferred"`; Markdown fallback: `- [x]` done,
`- [ ]` otherwise); the persisted enum `not-done | done | deferred` is never changed by rendering.

## review.collect

`checkpoint_view = { items[], open_questions[], qualification_gaps?[] }`; each
`qualification_gap = { field, coach }`; each `item = { task_id, title, rationale, evidence, context?, kind:
"task" | "context_section" | "binding_change", body? }` — `context` is the task's typed
execution-context block on `kind: "task"` items. The produced email draft is **not** an item kind here: it carries its
own verdict on its own surface (see `## render.email_draft`). Returns
`verdicts = { item_verdicts[], open_answers[], qualification_answers?[] }`;
`item_verdict = { task_id, verdict ∈ {accept|edit|reject}, note }`;
`open_answer = { question, answer }`; `qualification_answer = { field, answer }`.

**Call-site policy — batch or single-item, fixed per site.** `items[]` was always a list; which mode a site uses is
settled here, never chosen by the caller:

| Call site | Mode | `items[]` | `open_questions[]` | `qualification_gaps[]` |
| --- | --- | --- | --- | --- |
| `run-unbound` Step 3.5 — plan triage | **batch** | all retained tasks, in priority order | `[]` | `[]` |
| `run-unbound` Step 3.5 — material-edit re-confirm | single-item | the one re-shaped task | `[]` | `[]` |
| `run-unbound` Step 5 — close-out questions + qualification | no items | this run's list | `crm_update.qualification.gaps[]` or `[]` (one call when either list is non-empty; skip only when both are empty) |
| `setup-unbound` — `context_section` | single-item | one previewed section | `[]` | `[]` |
| `connect-tools` — `binding_change` | single-item | one proposed row edit | `[]` | `[]` |

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
(SET-STATUS's domain). `open_questions[]` and `qualification_gaps[]` are **never widget-rendered** — they remain
in-chat free text. The answer asymmetry is deliberate: `open_answers[]` are echoed in chat and held in-session, with
nothing written for them; each non-empty `qualification_answer` is an account fact routed through exactly one
work-account `capture-qualification` invocation. An empty or unanswered qualification gap writes nothing. The
checkpoint itself is write-free; all qualification persistence belongs to work-account's named authority.

Setup-time item kinds (outside the run loop): `context_section` — the item is one previewed context section, its
`task_id` slot carrying the section id (`process | messaging | assets | voice | state`); consumed by `skills/setup-unbound.md`
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
re-derived at render time). One card per group. Pure render; selection stays rep-owned. Pill text rules: call
pill `"Call · <recency>"`, appending `" · no recording"` **verbatim** when that call event's `evidence_status` is `missing`,
and appending **nothing** when it is `unknown` — no clause, no placeholder, no dangling `·`. `unknown` is never
rendered as `present` or as `missing`.
Email pill `"<N> unanswered email<s> · <recency>"`; both-signal groups show both pills, call pill first; an absent date
omits the recency clause entirely — no dangling separator. The muted subtitle reads
`<Humanized stage> · <Humanized topic>`, or whichever single part is known, or the humanized namespace singular
(`Account` / `Project`) when neither is. The full-width
**`Work <Name>`** button (name with `&`/punctuation flattened to words) is the selection utterance: the click writes
nothing and sends that text as the rep's selection turn, matched exactly as if typed (case-insensitive; ambiguity →
ask) — `render.slate` causes no write of any kind. An **empty slate renders no widget** (the existing "empty slate" chat
line stands); the `dropped` set is **never** widget-rendered (inspect-on-request stays chat-based).

**The interactive fragment is helper-first.** `build-slate` takes it from the bundled helper's `render` command, which
fills `resources/templates/slate-widget.html` under the rules above; hand assembly from that same template is the
**availability** fallback, never a second rule set. The rules above stay normative — the helper implements them.

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

## render.artifact

`artifact_view = { kind, title, filename, body_blocks[], source_task }`, read from the artifact file the handler
already wrote under the item's `drafts/` — nothing is regenerated or altered at render time. `kind` is a short label
naming the artifact type (e.g. `architecture_spec`) for card framing only, never a dispatch key; `title` is the
human-facing card heading; `body_blocks[]` is the artifact's content, chunked for display — **shaped like itself**,
the same principle `render.context_preview`'s `drafted_content` already states, not a literal HTML dump; `source_task`
is the task id the returned verdict maps to. **Render/capture:** the preview carries a **verdict footer** — Accept /
Reject buttons plus a free-text edit input and Submit — and returns `item_verdict = { task_id, verdict ∈
{accept|edit|reject}, note }`, where `task_id` is `source_task`. The artifact and the decision on it are **one
surface**; no separate checkpoint card follows it, and the verdict strings are the **existing** per-item sendPrompt
grammar — no second grammar exists. The amber `draft · not applied` pill states the boundary the footer does not
move: nothing is applied, sent, or renamed — generalizing `render.email_draft`'s `draft · not sent` pill for an
artifact that is adopted or applied rather than sent. The artifact's filename is cited in chat alongside the widget.

An **`edit` verdict is applied**, not merely recorded: the handler's own `apply-<artifact>-edit(namespace, slug,
source_task, note)` rewrites the artifact file — bounded to the fields the handler's own content contract declares —
**first**, appends exactly one `edit` line via `capture-feedback` **only** on success, and re-renders through this
capability so a fresh verdict is collected. The cycle repeats until accept or abandon; one log line per cycle,
append-only, and it is rep-bounded — each cycle takes a rep turn. Silence after a re-render writes nothing and leaves
the artifact at its last applied state. This capability adds **no** writer: the artifact file is one its own handler
already owns.

`render.artifact` is the **default** render capability every `execute` handler inherits per `task-registry.md` Part
B's Output-edit obligation — a handler that names a more specific capability (`draft-followup` keeps
`render.email_draft`) uses that one instead, and the two are never both called for the same artifact.

## render.crm_update

`crm_view` = the in-memory `crm_update` object `work-account` Step 6.5 handed back (`current_stage`,
`stage_recommendation { recommendation, to_stage, criteria[], unmet[], reason }`, the verbatim-carried `next_step`,
`product_gaps[]`, and the optional `qualification { framework, fields[]: { field, status: captured|missing, evidence?,
updated }, gaps[]: { field, coach } }` block when Step 6.5 emitted one) plus the persisted
`drafts/YYYY-MM-DD-crm-update.md` `filename`; nothing is re-evaluated at render
time. **Informational only:** zero affordances, returns nothing; no `review.collect` call follows, no `capture-feedback`
line is written, and silence has no meaning here. Card text rules: exactly one recommendation pill —
`advance to <stage>` / `no change` / `not applicable — <reason>`; a met exit criterion carries its source-prefixed
citation, an unmet one reads `no evidence this run`, and the criteria block is **omitted entirely on `not-applicable`**
(no criteria were evaluated); when `crm_view` carries a `qualification` block, a `Qualification (<framework>)` section
renders between the stage/criteria content and the next step — mirroring the draft's `## Qualification (<framework>)`
placed after `## Stage` (before `## Next Step`) — headed by an `N of M captured` count line (`M` the declared field
count, `N` the captured count — a count, never a percentage, score, or health grade), then one line per field in
declaration order: a captured field renders `- [x] <field> — <citation>` with its source-prefixed citation, a missing
field renders `- [ ] Missing: <field> — <coach hint>` with the hint verbatim from `gaps[].coach`, never generated or
re-worded; with no `qualification` block the section is **omitted entirely** — never an empty heading, never a
`0 of 0` line; the carried `next_step` renders in one line (or its explicit no-next-step reason); one
cited bullet per product gap, or the honest `none raised this run` line when empty. On the consuming skill's **simulate**
branch — the path taken wherever no write capability is confirmed bound, and on a decline — the persisted filename is
cited in chat with the explicit statement that **nothing was written to any external system**, and the rep applies it to
their real CRM if they agree. On its write branch the same view is presented for the rep's approval before anything is
sent, and what is cited afterwards is the outcome of that answer. Either way the stage recommendation stays advisory —
ENRICH remains the sole stage writer — and this capability itself performs **no** write and carries **no** affordance.

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

For a declared write-scoped row, `tool` reports live inventory presence independently of the status pill. A present
tool with no recorded eligibility path — neither replay-proven evidence nor the recovery-verified confirmations —
therefore renders with its tool named, `status: degraded`, and a consequence
that says production writes remain disabled and close-out simulates. `connected` is reserved for a positively confirmed,
production-eligible mapping; accepting a presence-only proposal cannot produce that label.

## render.setup_progress

`progress_view = { mode: first-run|refresh|resume, sections[]: { id: process|messaging|assets|voice|state,
status: done|active|pending | proposed-changes(n), title?, why?, coverage_note? } }` — the section
checklist `skills/setup-unbound.md` renders at its opening, after each section, on resume, and as the
refresh audit view; nothing is re-evaluated at render time. The section-id enum is fixed in D9 order
(`process | messaging | assets | voice | state`) — the same enum `review.collect`'s `context_section`
`task_id` slot carries. `proposed-changes(n)` is the refresh/audit status variant; `coverage_note` is an optional muted annotation (e.g. "mostly covered by deck").
`title` and `why` are optional rep-facing strings — second person, present tense, one sentence per `why`,
no internal noun (`run-state`, `predicate`, `artifact`, `enum`, `capability`, `slot`, `verdict`);
`skills/setup-unbound.md` owns their values in its step-1 table and this file never restates them.
Card text rules: one mode line (`first-run | refresh | resume`) at the top; one row per section, in D9
order, carrying the section `title` as its heading, its status pill
(`done | active | pending | proposed-changes(n)`), the muted `why` line when present, and the muted
coverage note beneath it when present. `title` absent ⇒ the heading is the section `id` verbatim; `why`
absent ⇒ its muted line is omitted entirely, the rule `coverage_note` already follows. The plain-Markdown
section-status list carries both fields under those same absent-field rules — ADR-1 field parity.
**Render-only, conveys nothing back:** zero affordances, no
verdict, no write — section verdicts flow through `review.collect` items of kind `context_section` (see
`## review.collect`), never through this surface.

## render.context_preview

`preview_view = { section_id, title?, why?, drafted_content, provenance[]: { block_ref, label },
gaps[] }` — the
drafted artifact `skills/setup-unbound.md` previews in its section loop, before each verdict; nothing is
regenerated or altered at render time. `drafted_content` is the artifact **shaped like itself** — the
thing being built, not a transcript of chat: a positioning block for `messaging`, the stage-ladder
pipeline for `process`, the six-column asset table for `assets`.
`title` and `why` are optional rep-facing strings under `## render.setup_progress`'s string rules, owned by
`skills/setup-unbound.md`'s step-1 table and never restated here.
Card text rules: the card heading is the `title`, with the muted `why` line directly beneath it and above
the content area. `title` absent ⇒ the heading is the `section_id` verbatim; `why`
absent ⇒ its muted line is omitted entirely, the rule `coverage_note` already follows. The plain-Markdown
card carries both fields under those same absent-field rules — ADR-1 field parity. Provenance labels
(`Evidence · <source> <locator>` / `Answer · rep`) are a **preview overlay only, never written to
files** — the accepted artifact strips them, and `title` and `why` are overlays under that same rule;
gaps render in the D13 blockquote voice and are the only
overlay content that persists (as D13 blockquotes in the written file). **Render-only, conveys nothing
back:** zero affordances, no verdict, no write — verdicts never flow through this surface; they belong
to `review.collect` items of kind `context_section` (see `## review.collect`).

## render.source_intake

`intake_view = { mode: first-run|resume|refresh, items[]: { id: sales-process|pitch-deck|positioning|brand|
messaging-guide|website|asset-list|own-writing, ask, why, status: pending|provided|interview|skipped, note? } }` —
the source-catalog checklist `skills/setup-unbound.md` renders when its step-2 intake opens and re-renders after each
item's answer; nothing is re-evaluated at render time. The item-id enum is the step-2 catalog's eight ids, in table
order. `ask` and `why` are required rep-facing strings under `## render.setup_progress`'s string rules, owned by
`skills/setup-unbound.md`'s step-2 catalog table and never restated here. `note` is
an optional muted annotation (e.g. "deck received", "no playbook") — the role `coverage_note` plays on
`render.setup_progress`.
Card text rules: one mode line (`first-run | resume | refresh`) at the top; one row per item, in catalog order,
carrying that item's `ask` as its heading, its status pill (`pending | provided | interview | skipped`), the muted
`why` line beneath it, and the muted `note` beneath that when present. `status` is required — an item carrying none
is a caller bug, never a render-time default, because a silently-`pending` item is indistinguishable from an answered
one. `note` absent ⇒ its muted line is omitted entirely, the rule `coverage_note` already follows. `ask`, `why` and
`note` are HTML-escaped, the rule section titles and coverage notes already carry. A narrowed view — the managed
path's single `own-writing` row, or resume's remaining items — is an ordinary use of this shape, never a variant. The
plain-Markdown item-status list carries every field under those same rules — ADR-1 field parity.
**Render-only, conveys nothing back:** zero affordances, no verdict, no write — intake answers are given in chat, and
this surface produces no `review.collect` item of any kind.

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
  of `granola`, `zoom`, `gong`, or any concrete provider tool name. Core-scoped: it guards this core pipeline skill
  alone, never an overlay handler's `## Capabilities` table.
- **Edge cases.** Identical transcripts from two providers → priority picks one, the other discarded silently; confident
  beats fuzzy; all fuzzy/missing → `missing`; a transient provider error → `not_found` for that `call_ref`, others
  still evaluated (Pattern 2).
- **Write boundary.** Every provider is read-scope only; Zoom's `create_new_file_with_markdown` is a write tool and is
  **NOT bound** (ADR-4).



## Out of scope (do NOT add here)

- Any **external write-scoped** capability beyond the ones a binding table above *explicitly declares*:
  `email.queue_draft`, `gmail.send`, `gmail.modify`, `gmail.label` (Growth FR28–FR34). Gmail is
  list-and-read only — the discovery window in the run loop, the rep's own SENT mail at setup — never
  send, reply, draft-into-Gmail, label, archive, or modify.
- Bindings/adapters for other runtimes (Copilot) — deferred, per the indirection rule.
