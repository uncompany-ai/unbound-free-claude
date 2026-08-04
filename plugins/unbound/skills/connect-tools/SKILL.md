---
name: connect-tools
description: Dual-entry environment readiness check. Derives the required capability set from runtime/tool-bindings.md's own binding tables, enumerates the live runtime's tool inventory, matches the two, proposes binding-row updates one at a time, and reports every gap with its concrete run-time cost. Invoked standalone by the rep ("check my connections", "am I ready to run", after adding or removing a connector or switching runtimes) and by setup-unbound at its readiness gate — NOT part of the run-unbound loop.
tier: all
---
# connect-tools

Environment readiness check with two entries: the rep invokes it standalone ("check my
connections", after any connector or runtime change), or `setup-unbound` invokes it at its
readiness gate. It derives the required capability set from `runtime/tool-bindings.md`, enumerates
the live tool inventory, matches the two, proposes binding-row updates one at a time, and reports
every gap with its run-time cost. All environment access is read-only, and it never auto-runs
inside the `run-unbound` loop.

## Reads

- `runtime/tool-bindings.md` — the requirements source (its binding tables, including the declared future write gate) and the one file this skill maintains.
- The runtime's live tool inventory — inspected read-only in-session; concrete tool names enter the conversation only from here.
- Logical capability `review.collect(checkpoint_view)`, items of kind `binding_change` — the propose surface; item grammar and verdict routing live in `runtime/tool-bindings.md` under `## review.collect`.
- Logical capability `render.connections(connections_view)` — the report surface; view shape and board text rules live in `runtime/tool-bindings.md` under `## render.connections`.

## Procedure

**1 — Derive.** Read the binding tables in `runtime/tool-bindings.md`; their logical-capability
column is the requirements list — no second list exists anywhere.

- Carry each capability's criticality from the file's own framing, never from a restated row inventory: optional-degraded rows degrade as they state, provider rows degrade to `missing`, render rows degrade to their documented fallbacks, a declared-but-unbound future gate (e.g. `crm.write`) resolves to its documented fallback until bound — reported `missing`/`degraded` with that fallback as its consequence — and rows carrying no degradation note are hard-required.
- An absent or unparseable bindings file stops the check — see Invariants.

**2 — Enumerate.** Inspect the runtime's actual tool inventory as a read-only pass over what the
live session exposes. Concrete names arrive from the environment into the conversation, and reach
`runtime/tool-bindings.md` only through accepted proposals.

**3 — Match.** Classify every derived capability against its binding cell and the enumerated
inventory: *resolved* (the bound tool is present), *resolvable* (a suitable tool exists but the
binding row is absent or stale), or *unresolved* (nothing suitable — the capability degrades per
its criticality).

**4 — Propose.** For each resolvable or stale row, present one `review.collect` item of kind
`binding_change` — one item per call, never batched — naming the capability, the concrete tool
found, and the exact row edit.

- accept ⇒ apply exactly that one row edit; edit ⇒ fold the note into the proposal and re-present; reject ⇒ drop the proposal.
- The write boundary around every verdict is in Invariants.

**5 — Report.** Assemble `connections_view`: one entry per derived capability plus the
ready-or-exceptions `verdict`, matching the shape declared in `runtime/tool-bindings.md` under
`## render.connections`.

- Each entry carries `capability`, `status` (`connected | missing | degraded`), `tool` only when bound from the live environment, and a `consequence` line on every `missing` or `degraded` row.
- Render via the logical `render.connections` capability only on positive confirmation that the widget tool is present in the runtime's tool list.
- Otherwise emit the plain-Markdown capability table plus verdict line — identical content, never an assumed rich UI.
- Write each `consequence` in the honest-degradation voice, derived from the bindings file's own degradation notes — for example: no transcript source ⇒ calls worked `transcript: missing`; no email source ⇒ discovery is calendar-only; no `web.fetch` ⇒ website intake unavailable; no widget tool ⇒ plain-chat surfaces; no CRM write connected ⇒ CRM updates are simulated / drafted locally.
- Close per entry point: standalone ⇒ end with this report as the session summary; gate entry ⇒ hand the identical report back to the invoking `setup-unbound` — behavior identical, framing only.

## Writes

- `runtime/tool-bindings.md`, and nothing else — this skill is its sole writer; each write is exactly one row edit, leaving every unaffected row byte-unchanged.
- No `company/*`, `state/*`, `accounts/`, or `projects/` file is ever touched, and no external write of any kind is ever made.

## Invariants

- An absent or unparseable `runtime/tool-bindings.md` ⇒ name the problem and stop; never reconstruct requirements from memory.
- Never write without an accept verdict on the one `binding_change` item covering that row.
- Never append to `feedback-log.jsonl` — that log stays the run loop's prioritization instrument.
- Never name a concrete tool from this file's prose — concrete names enter only per step 2's direction of flow.
- Never a silent gap: every unresolved capability is reported with its concrete run-time consequence.

---

## Bundled resources (Cowork)

> This is the **standalone** Cowork build of connect-tools. The logical capability map
> (`render.connections`, `review.collect`, and friends) ships in this same skill folder as
> `resources/tool-bindings.md`, and the interactive board render for `render.connections` is
> pinned by `resources/templates/connections-widget.html`. Resolve capabilities from those
> bundled copies — do not expect a `runtime/` tree. The bundled bindings copy is the
> requirements reference in a zip-only install; the file this skill maintains is the working
> tree's `runtime/tool-bindings.md` where one exists. All data and write paths remain relative
> to the working directory Cowork is operating in (the `unbound/` tree).
