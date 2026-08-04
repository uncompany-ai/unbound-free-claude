---
name: setup-unbound
description: Onboarding orchestrator for Unbound. Builds the company context tree — company/process.md, company/messaging.md, company/assets.md — plus the initial state/run-state.yaml, and closes with a connect-tools readiness verdict. Detects its mode from the files alone (first-run on an empty tree, resume on a partial one, refresh/audit on a complete one). Invoked directly by a rep or facilitator ("set up Unbound", "onboard me", "configure my company context", "refresh my company context", "audit my setup") — it never auto-runs and is never invoked by run-unbound.
tier: all
---
# setup-unbound

Onboarding orchestrator — the second root orchestrator beside `run-unbound`, invoked directly by a
rep or facilitator; it never auto-runs and is never invoked by `run-unbound`. Its posture is
extract-then-confirm: provided sources and interview answers do the talking, every artifact is
previewed and accepted before it is written, and the files themselves are the only state.

## Reads

- `company/process.md`, `company/messaging.md`, `company/assets.md`, `state/run-state.yaml` — read-only inspection at entry, against the validity predicates in Procedure step 1.
- `accounts/*/context.md` YAML frontmatter — account-only, read-only input to the Procedure step-7.5 orphan scan; the scalar `stage:` value and directory slug are the complete read surface.
- Logical capability `render.setup_progress(progress_view)` — the section-checklist surface; view shape and Markdown fallback live in `runtime/tool-bindings.md` under `## render.setup_progress`; surface resolution per `runtime/adapters/cowork.md`.
- The source pool (Procedure step 2) — session working material read via three logical paths: files shared in chat, `content.search`/`content.get`, `web.fetch`.
- Logical capabilities `render.context_preview` and `review.collect` (Procedure steps 3–4) — the section-loop preview and verdict surfaces; view shapes, item grammar, and routing live in `runtime/tool-bindings.md`; surface resolution per `runtime/adapters/cowork.md`.
- Logical capability `render.connections(connections_view)` (Procedure step 5) — the closing verdict-banner surface; view shape and board text rules live in `runtime/tool-bindings.md` under `## render.connections`; surface resolution per `runtime/adapters/cowork.md`.
- `skills/standalone/connect-tools.md` — the readiness-gate step invoked at Procedure step 5, composed per its gate entry; its handed-back report is the step's input.
- `runtime/tool-bindings.md` itself is never read by this skill — capability derivation belongs to `connect-tools`.

## Procedure

**1 — Detect the mode (read-only; the files are the only state).**

1. State what setup builds: the three `company/*` files (`process.md`, `messaging.md`, `assets.md`), the initial `state/run-state.yaml`, and the closing readiness verdict.
2. Render the section checklist via the logical `render.setup_progress` capability — section ids `process | messaging | assets | state`, in that fixed order; in first-run mode all four are pending.
  - Fallback: the plain-Markdown section-status list, identical content; resolution rule per `runtime/adapters/cowork.md`.
3. Evaluate each artifact against its validity predicate — valid-present or not. A predicate reads an absent *directory* identically to an absent *file* — the artifact is simply not valid-present; no error is surfaced, and step 1 stays a pure read:
  - `company/process.md` — exists, non-empty, carries the authoritative-enum header prose, and defines ≥ 1 stage as a heading whose token is lowercase/kebab, each with a definition and entry/exit criteria.
  - `company/messaging.md` — exists, non-empty, and carries the full downstream section contract: positioning (what/who/value proposition), differentiation pillars, proof points, objection handling, voice/tone.
  - `company/assets.md` — exists with the fixed six-column header `| Asset | Vertical | Use case | Stage | Pain point | Link |`, every Stage cell in the process enum or `any`, and a freshness note with a named owner; zero data rows is valid.
  - `state/run-state.yaml` — parses to a mapping with `last_run` (ISO 8601 with offset), `timezone` (IANA), and `events` (a list, empty on a fresh seed); keys beyond those three (for example `scan_window`) are permitted.
4. Decide the mode from those four results alone — no sidecar tracker, no marker file of any kind:
  - All four absent or template-empty ⇒ **first-run**. "Template-empty" = file absent, zero-length, or a `.gitkeep`-only directory — the working directory empty, or any namespace directory absent, reads the same way. A truly empty folder is the canonical first-run.
  - Some valid-present, some not ⇒ **resume**, continuing from the first invalid or absent artifact in the fixed section order.
  - All four valid-present ⇒ **refresh/audit**.
  - A present `state/run-state.yaml` that does not parse at all is not a resume target — see Invariants (unparseable state).
5. Announce the detected mode to the user.
6. Re-render progress to match: first-run ⇒ all sections pending; resume ⇒ completed sections done, the continuation target active; refresh/audit ⇒ the audit framing (the `proposed-changes(n)` status variant, shape unchanged).
7. In refresh/audit mode, continue past the announcement into the refresh branch (step 7).

**1.5 — Prepare the working tree (slot).** Contract: the first write in the flow — idempotent, directory-only, content-free.

1. In first-run and resume modes, before the first section write, create each of `company/`, `state/`, `accounts/`, `projects/` where absent — an existing directory is left untouched, and a directory is only ever created, never removed, emptied, or renamed. This is the create-if-absent idiom `bootstrap-context` already carries for slug directories, generalized to the four namespace directories.
2. `accounts/` and `projects/` are created empty — directories only. Setup writes no file into either, ever; their content (`context.md`, drafts, task lists) stays bootstrap-context/run-loop owned — see Writes.
3. In refresh/audit mode this slot is a no-op by construction: all four artifacts are valid-present, so every directory already exists.
4. Creation is silent — no narration, no progress event; the section checklist already communicates progress, and an existing tree makes this step invisible by design.

**2 — Source intake & pooling.** Contract: one source pool, gathered once here, carried into every section that follows.

1. Invite the user to hand over whatever they have — any subset, in any order, or nothing at all.
  - Six best-grounding source types, every one optional: pitch deck, sales playbook / process doc, ICP or positioning doc, messaging guide, asset list, company website URL.
2. Offer three intake paths, each named by logical capability only:
  - Files shared directly in chat.
  - Drive documents via `content.search`/`content.get` — read only on the user's explicit go-ahead.
  - Website pages via `web.fetch`.
  - Every path is read-only: no external write of any kind, and no file write anywhere in this step — see Writes.
3. Gather everything provided into the single source pool — session-held working material, never written to the repo.
  - Within this session's flow, later sections re-read the pool: a source is never re-fetched, and a source already given is never re-asked.
  - The pool carries the credential-hygiene standing rule — see Invariants (credential hygiene).
4. Name any unavailable intake capability to the user — it disables only its own path, never the outcome.
  - `web.fetch` is optional-degraded: unavailable ⇒ website intake named unavailable, setup proceeds on the remaining sources.
  - `content.search`/`content.get` unavailable ⇒ Drive intake named unavailable; chat files and the interview still stand.
5. Close the step with an honest recap of the pool, named per source.
  - A source that failed to fetch or read is named plainly in the same recap; setup continues on the remaining sources.
6. Treat "I have nothing" as a first-class path: proceed straight to the guided interview in the section loop, with no retry pressure and no error framing.

**3 — Section loop over `process`, `messaging`, `assets` (slot).** Contract: one extract-then-confirm pass per section, in that order.

One generic pass, applied per section. The loop visits every section not yet valid-present — all of them on first-run, from the step-6 entry point on resume — and never reopens a completed one:

1. **Gather** — re-read the step-2 session pool; its no-re-fetch, no-re-ask contract (step 2) governs every section's read.
2. **Extract** — draft the section from the pool with a provenance label on every block: `Evidence · <source> <locator>` (for example `Evidence · deck p.4`, `Evidence · website /pricing`, `Evidence · playbook §3`) or `Answer · rep`. A block with no source becomes a gap marker (the write step's blockquote form) or a targeted question — never a plausible invention.
3. **Gap interview** — ask only for what extraction couldn't cover: one focused question at a time, bounded to the gap, never a form-dump; each answer folds into the draft as an `Answer · rep` block. A pooled source contradicting the user's direct answer resolves in the answer's favor, noted in the preview. Extraction and interview alike sit under the credential-hygiene standing rule — see Invariants.
4. **Preview** — render the draft via the logical `render.context_preview` capability: the artifact shaped like itself, gaps and provenance visible; view shape and Markdown fallback live in `runtime/tool-bindings.md` under `## render.context_preview`; surface resolution per `runtime/adapters/cowork.md`.
5. **Verdict** — collect exactly one `review.collect` item of kind `context_section`, its `task_id` carrying the section id; item grammar and verdict routing live in `runtime/tool-bindings.md` under `## review.collect`. Accept ⇒ this skill performs the section's file write (next step); edit ⇒ the note is applied to the draft and re-previewed; reject ⇒ the section is re-extracted or re-interviewed afresh. No `state/feedback-log.jsonl` line, ever.
6. **Write whole** — on accept, write the section's file complete, in a single write, creating the file's parent directory if absent (see Writes). Provenance labels are a preview-only overlay, never written into `company/*`; an unresolved gap persists into the file only as the exact blockquote `> **Gap:** <what's missing>. Fill via a setup-unbound refresh.` The written file passes its step-1 validity predicate and `runtime/lint.sh` at the moment of writing — a post-write failure is surfaced as a bug, never shrugged off.
7. **Progress** — re-render via `render.setup_progress` with the section marked done.

Per-section specifics:

- **`process` → `company/process.md`.** Extract the stage ladder — stage names, a definition, and entry/exit criteria per stage; playbook, process doc, and deck are the usual carriers. The draft previews as a pipeline. The accepted file lands in its step-1 predicate shape — authoritative-enum header prose, then ≥ 1 stage, each a lowercase/kebab-token heading with definition and entry/exit criteria; its self-documenting schema prose is adapted from the hand-authored original, never copied verbatim, and its tokens stay stable — renaming one silently orphans every account already tagged with it.
- **`messaging` → `company/messaging.md`.** Extract the five contract parts from their usual pooled carriers — positioning (what/who/value proposition) chiefly from the ICP or positioning doc, deck, and website; differentiation pillars from the deck and website; proof points from case-study or results material in the deck or on the site; objection handling from the playbook or messaging guide; voice/tone from the messaging guide and the site's own copy — pairings are guidance, not a closed rule. The draft previews as a positioning-block card. The accepted file lands in its step-1 predicate shape. Its self-documenting schema prose is adapted from the hand-authored original — naming its downstream readers `work-account` and `draft-followup` and its source-of-truth stance — never copied verbatim. An ungrounded part persists via the write step's gap blockquote — for example `> **Gap:** no proof points found in provided sources. Fill via a setup-unbound refresh.`
- **`assets` → `company/assets.md`.** Build the asset index — one row per asset across the fixed six columns `| Asset | Vertical | Use case | Stage | Pain point | Link |` — chiefly from a pooled asset list when one was given, plus collateral named in the deck, on the website, or by the user in the gap interview. Every `Stage` cell draws from the `process.md` enum — authored in this session's `process` pass or standing valid on disk on a resume — or `any`, permitted only in this file; the freshness note needs a named owner, and a missing owner is a targeted gap question, never an invented name. A `Link` cell has exactly two admissible origins: pasted verbatim by the user, or verified resolvable during the session via the logical `content.get` capability — a per-link resolvability read on the already-pooled path, distinct from a source re-fetch. A link that fails verification, or a claimed asset with no link and no user-provided location, stays out of the table and is surfaced plainly in the preview — never construct, guess, or repair a URL. Zero data rows is a valid accepted outcome — an honestly-empty index beats a fabricated one. The draft previews as the asset-table card — the actual table shape. The accepted file lands in its step-1 predicate shape; its self-documenting schema prose is adapted from the hand-authored original — naming its downstream reader `draft-followup`, the first-pass asset matcher, and restating the stage-token stability warning against the user's own enum, an orphan stage value silently breaking matching — never copied verbatim.

**4 — State initialization (`state`) (slot).** Contract: one lightweight checkpoint — two rep-answered facts, one preview, one verdict, one whole write. Deliberately not a section-loop pass: no pool read, no provenance overlay, no gap markers — both values are rep answers by construction.

1. **Confirm the timezone** — propose an IANA zone when session evidence offers one; the user's confirmation is the contract. Record the confirmed IANA zone name, never a bare UTC offset.
2. **Resolve the baseline** — ask how far back the first run should look, one focused question; the answer resolves to a full ISO-8601 `last_run` by date math done in prose in the confirmed zone — no code, no scripts.
  - The recorded offset is the confirmed zone's offset at the resolved date — a baseline across a DST boundary carries that date's offset, not today's.
  - Present both resolved facts back to the user before any verdict.
3. **Preview** — render the seed shaped like itself via `render.context_preview` (section id `state`): the three-key YAML block exactly as it will be written, comment prose visible.
4. **Verdict** — collect exactly one `review.collect` item of kind `context_section`, `task_id` = `state`; routing and the no-log-line rule are the step-3 verdict rules, consumed unchanged. On the checkpoint: accept ⇒ write (next step); edit ⇒ the corrected value(s) fold in and the seed re-previews; reject ⇒ the checkpoint re-confirms from the top, both facts re-asked.
5. **Write whole, once** — on accept, write `state/run-state.yaml` under the step-3 write-whole rule (complete, single write, creating the file's parent directory if absent, predicate and `runtime/lint.sh` clean at the moment of writing): exactly the three required keys — `last_run` (full ISO 8601 with offset), `timezone` (IANA zone name), `events: []` — with `scan_window` omitted as the documented default.
  - Carry the hand-authored original's self-documenting comment block in adapted, schema-only form: the three required keys, the optional `scan_window` key with its when-absent default (`now`, unbounded), the event record shape as run-loop-owned, and the hand-edit-must-stay-valid rule.
  - Never carry that file's event records, dates, or any company-specific value into a fresh seed — setup seeds `events: []` and never writes an event record; the write boundary and `last_run` ownership live in Writes. An empty `events` list is a clean empty slate, not an error.
6. **Progress** — re-render via `render.setup_progress` with `state` marked done.

**5 — Readiness gate & verdict (slot).** Contract: invoke `connect-tools` at its gate entry, then close the session on its report.

1. **Invoke** — call `connect-tools` at its gate entry exactly as `run-unbound` invokes pipeline steps: defined input, this invocation context; defined output, the binding/degradation report that skill assembles in the `connections_view` shape (`runtime/tool-bindings.md`, `## render.connections`). Never proceed to a verdict without the report.
2. **Receive, never re-derive** — the report is consumed as handed back: this step performs no capability derivation and no tool-inventory enumeration (see Reads — capability derivation belongs to `connect-tools`). Any `binding_change` proposal during the gate runs under `connect-tools`' own grammar and sole write authority; this step collects no `review.collect` item and writes nothing.
3. **Re-check the artifacts** — re-evaluate the four step-1 validity predicates read-only against the files on disk, never assumed from session memory; the same predicates, consumed from step 1 — a resume entry or a mid-session hand-edit is exactly what this re-check catches.
4. **Compose the verdict** — READY TO RUN ⇔ all four predicates hold ∧ every hard-required capability in the report is resolved; otherwise READY EXCEPT X, each X exactly one unresolved hard-required capability or one invalid or absent artifact, carrying its concrete run-time consequence and what unlocks it.
  - A capability exception carries the report's own consequence and unlock content, in its honest-degradation voice; an artifact exception's unlock is the resume path — re-invoke `setup-unbound`, which continues at that artifact per step 1.
  - Optional-degraded capabilities degrade as their binding rows document: they surface as `degraded` board rows with consequences, never as exceptions, and never block READY TO RUN. Which capabilities are hard-required is the report's own classification, carried from the bindings file's framing — never enumerated here.
5. **Render and close** — render the closing banner via the logical `render.connections` capability: the handed-back report's rows unchanged, the composed verdict in the declared `verdict` slot, artifact exceptions folded into its `exceptions[]` what/unlocks shape. Fallback: the plain-Markdown capability table plus verdict line, identical content; resolution rule per `runtime/adapters/cowork.md`. Close the session on the verdict plus one invitation to start the first `run-unbound` — on READY EXCEPT, conditioned honestly on what to unlock first. The session never closes without the readiness verdict.
6. **Falsifiability** — READY TO RUN claims `runtime/lint.sh` exits 0 on this tree; a ready verdict followed by a lint failure is a bug to surface, never a shrug.

**6 — Resume continuation (slot).** Contract: on a step-1 resume decision, the flow enters at the first invalid or absent section in the fixed order and runs the remaining slots from there.

1. **Enter** — the step-1 resume decision routes here: its predicates locate the entry point, the first invalid or absent artifact in the fixed section order.
  - The step-1 progress re-render shows completed sections done, the continuation target active; the files alone carry the interruption — no sidecar state of any kind.
2. **Continue** — from the entry point, run the remaining flow exactly as first-run would:
  - Source intake (step 2) re-runs scoped to what the remaining sections need — the session-held pool did not survive the interruption, so it is re-gathered only as needed.
  - The user is told which sections are already done; sources are requested only for what remains — a source that only fed completed sections is never re-requested. The within-session no-re-fetch, no-re-ask contract (step 2) then governs as usual.
  - The section loop (step 3) visits only sections not yet valid-present, per its own rule; the state checkpoint (step 4) runs only if `state/run-state.yaml` is invalid or absent; the gate (step 5) always runs before close.
3. **Never re-ask** — a completed section is never re-asked, re-confirmed, or re-verdicted.
  - An explicit ask to redo one is not a resume: it routes through the refresh grammar — the refresh branch (step 7).
  - A re-invocation that finds all four artifacts valid is refresh/audit by the step-1 decision — this step never runs there.
4. **Price the trade-off** — interruption safety is constructional, not procedural: the guarantee is the write protocol the loop already carries, and this step adds no recovery machinery, checkpoint file, or draft persistence.
  - The only writes in this skill are whole-file-after-accept in dependency order — the step-3 write-whole rule and the step-4 write — and the write of file N is never gated on file N+1.
  - A session killed at any instant leaves each artifact either untouched or complete-and-valid — no partially written file is possible, no repair path is needed.
  - The price: a mid-section interruption loses only that section's un-accepted draft, never an accepted artifact — abandonment costs remaining time, not completed work.

**7 — Refresh & audit (slot).** Contract: the diff-and-propose form of steps 2–4 — audit the existing artifacts against a fresh source pool, present the per-section proposed changes, and apply only what the user accepts. Every consumed rule is a pointer to a carried step, and every write is accept-gated (see Writes).

1. **Enter** — the step-1 refresh/audit decision routes here: all four artifacts valid-present (step 1.4), the mode announced (step 1.5), progress already re-rendered in the audit framing (step 1.6).
2. **Re-intake** — offer to re-read the prior source types or take new ones, under the step-2 contract consumed whole.
  - Consumed unchanged from step 2: the six optional source types, the three read-only paths, and the pool-once, no-re-fetch/no-re-ask, degradation, and credential-hygiene rules.
  - "Nothing new" is a first-class answer — the step-2.6 "I have nothing" rule, consumed here for declining re-intake.
  - An empty pool leaves nothing to diff: the audit completes with every section stated unchanged, and the session closes cleanly with zero writes.
3. **Diff per section** — for `process`, `messaging`, `assets` in that fixed order, extract candidates from the pool under the step-3 extract rules and per-section specifics, provenance labels included.
  - Diff the extracted candidates against the section's existing file and collect the proposed changes — the diff replaces the gap interview as what happens next.
  - A proposed change is one coherent block-level unit, named per artifact: a stage (heading, definition, entry/exit criteria) in `process`; a contract part, or a block within one, in `messaging`; a table row in `assets`.
  - A change is never a whole-file replacement and never sub-word noise.
  - A standing gap blockquote (the step-3.6 form) that new evidence can cover becomes an ordinary fill-a-gap proposal — the blockquote's own documented promise coming due.
  - The `state` section is deliberately not audited — it reopens only on the user's explicit ask.
  - A corrupt `state/run-state.yaml` stays stop-and-surface — see Invariants (unparseable state).
4. **Audit view** — once all three sections are diffed, render once via `render.setup_progress`, mode `refresh`: each section carries its `proposed-changes(n)` status and a `coverage_note` freshness signal (for example "3 proposals from new positioning doc", "unchanged") — the declared view shape, unchanged.
  - A section with zero proposed changes is stated as unchanged and skipped in everything that follows.
  - Fallback: the plain-Markdown section-status list, identical content; resolution rule per `runtime/adapters/cowork.md`.
5. **Proposal loop** — for each section the audit view left with `proposed-changes(n)`, n > 0, work its proposals one at a time, in file order, top to bottom.
  - One proposed change is one card: current text → proposed text → motivating source, the source in the step-3.2 provenance label form (`Evidence · <source> <locator>`).
  - Before a `process` proposal that renames or removes an existing canonical stage token can expose a verdict, enumerate every `accounts/*/context.md` candidate.
  - The scan reads no `projects/` path.
  - Parse only each candidate's YAML frontmatter.
  - Compare its scalar `stage:` value exactly with the affected old token.
  - Derive each affected account slug from the candidate's directory.
  - If any candidate cannot be read or its frontmatter cannot be parsed, name every such path and keep the card un-verdictable. Never present a partial count as complete.
  - After a complete scan, enrich the same card's `drafted_content` with the exact affected-account count and every affected slug, or the exact text `no accounts affected`.
  - When the count is nonzero, state plainly that those accounts' `stage:` values will no longer match any canonical enum token if the proposal is accepted.
  - A `process` proposal that only adds a new stage follows the ordinary proposal path with no orphan-scan block.
  - The card renders via `render.context_preview` — the declared `preview_view` shape, unchanged. Fallback: the plain-Markdown card, identical content; resolution rule per `runtime/adapters/cowork.md`.
  - The verdict is exactly one `review.collect` item of kind `context_section`, its `task_id` carrying the section id — one item per call, never batched.
  - Accept ⇒ the change is applied to the session-held working copy of the section, never directly to disk.
    - For a scanned `process` proposal, only that working copy changes; `accounts/` remains under the Writes never-list.
  - Reject ⇒ the existing text stands.
  - Edit ⇒ the note folds into the proposal and the card re-presents.
    - If the edit changes the affected old token, discard the stale scan result.
    - Repeat the scan-and-enrichment branch before re-presenting the card or exposing a verdict.
  - Routing is the step-3.5 verdict rule, consumed unchanged, its no-log clause included — this skill performs the eventual write.
6. **Write-back** — after all of a section's proposals are verdicted, apply only the accepted diffs to the section's content — never a wholesale rewrite.
  - Every un-proposed block — hand-edited or unchanged — and every rejected-proposal block is byte-identical in the result.
  - Until that moment the on-disk file is untouched: accepted changes accumulate only in the session-held working copy, so a session killed mid-loop loses un-verdicted proposals, never an on-disk artifact — the step-6.4 constructional guarantee, extended unchanged to refresh.
  - The write is the step-3.6 write-whole rule, consumed unchanged: the file written whole, once, schema-valid — predicate and `runtime/lint.sh` clean at the moment of writing, provenance preview-only.
  - A section with every proposal rejected is not rewritten; a session with zero accepts performs zero writes.
  - A section file found unparseable or predicate-invalid mid-refresh — a mid-session hand-edit is what this catches — stays stop-and-surface: see Invariants (unparseable state).
  - Re-render progress via `render.setup_progress` after each section's write.
7. **Close** — after the last section's verdicts, re-render the audit view once more and close the session on it: each worked section's applied/rejected outcome rides its `coverage_note` (for example "2 applied, 1 rejected"), zero-proposal sections still "unchanged".
  - The step-5 readiness gate is not mandatory on refresh: the tree was valid at entry, and every write preserved validity by construction — predicate plus lint at write time.
  - The close carries one reminder: `connect-tools` runs standalone if connectors changed.
  - An audit-only session — zero accepts — closes with zero writes and no gate; an all-unchanged audit never reaches the loop at all: it states the result and closes cleanly.

## Writes

- The empty directories `company/`, `state/`, `accounts/`, `projects/` — created where absent by step 1.5 (and, per file write, by the write clause's own parent-dir-if-absent rule); directory creation only, idempotent, never a removal or a mutation of anything existing.
- `company/process.md`, `company/messaging.md`, `company/assets.md` — this skill is their sole writer; each file is written whole, once, behind the accept verdict on its `context_section` item.
- `state/run-state.yaml` — setup-time initialization only, behind its accept verdict; advancing `last_run` afterward stays with the run loop.
- Never written by this skill: the **content** of `accounts/` and `projects/` — step 1.5 creates those two empty *directories*, but every file under them (`context.md`, drafts, task lists) stays bootstrap-context/run-loop owned — `state/feedback-log.jsonl` (no line, ever — that log stays the run loop's prioritization instrument), `runtime/tool-bindings.md` (sole writer: `connect-tools`), and anything external.
- With steps 1–7 in this file, steps 1 and 2 remain pure reads — neither mode detection nor source intake performs a write of any kind; the first write in the flow is step 1.5's empty-directory creation — step 5 adds no write of its own (nothing is written at the gate; `runtime/tool-bindings.md` stays under the never-list above) — step 6 likewise adds no write of its own: resume routes into the same step-1.5 scaffolding and the same accept-gated section and state writes — and step 7 performs the accepted-diff whole-file rewrites of `company/process.md`, `company/messaging.md`, and `company/assets.md`, each behind the accept verdict(s) on its own `context_section` item(s); `state/run-state.yaml` is never written on the refresh path (the `state` section is not audited — step 7.3).

## Invariants

- Unparseable state stops the session: a present `state/run-state.yaml` that fails to parse is named to the user and left untouched — never silently recreated, repaired, or overwritten. Any other malformed-but-present artifact is likewise named at detection, never silently repaired. Scaffolding never runs over an existing file: step 1.5 and the parent-dir clauses create directories only, so this stop-and-surface rule is unreachable by them.
- Scaffolding is idempotent and interruption-safe: creating a directory where absent mutates nothing existing, re-running or resuming repeats it harmlessly, and an empty directory is never a partial artifact — present-or-absent are both valid states. The step-6.4 constructional guarantee — every artifact untouched or complete-and-valid at any kill point — is preserved unchanged, with no repair path introduced.
- Slot boundaries: every declared slot in this file carries its body. Never improvise an interview, an extraction, a scan, or a write beyond the declared flow.
- Credential hygiene: credentials, API keys, tokens, and personal contact data found in any pooled source are ignored for distillation — never written into `company/*` or `state/*`, never quoted back beyond what naming the exclusion requires; the rule binds every read of the pool, not intake alone.
- Never write without an accept verdict on the covering `context_section` item; silence is never a verdict.
- Never fabricate content for any artifact — a gap is surfaced, never filled in.
- A render capability whose interactive surface is unconfirmed resolves to its documented plain-Markdown fallback — never an assumed rich UI.

---

## Bundled resources (Cowork)

> This is the **bundled** Cowork build of setup-unbound. The readiness-gate slot (Procedure
> step 5) resolves `connect-tools` from `resources/connect-tools.md` in this same skill
> folder — do not expect a separate connect-tools install. The logical capability map ships
> as `resources/tool-bindings.md`, and the pinned widget layouts ship under
> `resources/templates/`. Resolve capabilities from those bundled copies — do not expect a
> `runtime/` tree. All data and write paths (`company/*`, `state/run-state.yaml`) remain
> relative to the working directory Cowork is operating in (the `unbound/` tree).
