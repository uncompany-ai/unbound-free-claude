---
name: write-crm
description: Close-out skill that applies the CRM update for the worked item via an explicit capability-gated write/simulate fork. Invoked by run-unbound at the Step 5 CRM close-out sub-beat (composition slot 8) with the in-memory crm_update object work-account handed back. RESOLVE checks the logical crm.write capability; when bound it would push the field-level update (write branch — authored but inert), and when unbound or unconfirmed it falls back to the live simulate branch — persisting drafts/YYYY-MM-DD-crm-update.md and rendering "(simulated)". NOT part of the run loop's task dispatch and NOT a task-registry handler (external write lives outside the Handler Contract).
tier: all
---
# write-crm

Close-out apply step of an Unbound run (composition slot 8) that owns the **APPLY** half of the CRM
update — the write-vs-simulate boundary concern. `work-account` Step 6.5 computes *what* the CRM
should hold (the grounded `crm_update` object); `write-crm` decides *how* it lands. Invoked by
`run-unbound` at the Step 5 CRM close-out sub-beat (after the email-draft verdict beat), taking the
in-memory `crm_update` object `work-account` handed back. Its `## Procedure` is an explicit **RESOLVE → APPLY** fork gated
on the logical `crm.write` capability: the write branch is authored but inert (unreachable while
`crm.write` is unbound), and the simulate branch is the live path — the verbatim current behavior.
Names only logical capabilities (ADR-6); it is not a task-registry handler — the external write
lives outside the Handler Contract (a numbered composition-seam slot is not the same as a registry handler).

## Reads

- In-memory `crm_update` object (handed back by `work-account` Step 6.5, forwarded by `run-unbound` Step 5) — `current_stage`, `stage_recommendation { recommendation, to_stage, criteria[], unmet[], reason }`, the verbatim-carried `next_step`, `product_gaps[]`. Nothing is re-evaluated here.
- The selected item's `(namespace, slug)` and its `accounts|projects/<slug>/drafts/` path — the persist target on the simulate branch.
- `state/run-state.yaml` — the run's `timezone`, for the filename date (read-only; never written here).
- Logical capability `crm.write(crm_update)` — the RESOLVE gate; declared but unbound in every runtime (write boundary closed — ADR-4).
- Logical capability `render.crm_update(crm_view)` — the informational close-out card / Markdown section; never a concrete tool name.

## Procedure

**1 — RESOLVE.** Select the branch by checking the logical `crm.write` capability, following the
render-resolution rule (positive confirmation … else the documented fallback — never assume):

- `crm.write` **positively confirmed bound** in the runtime's tool list → branch = **write** (Step 2).
- Absent, or presence cannot be confirmed → branch = **simulate** (Step 3) — the documented fallback.
- `crm.write` is unbound by design in this change, so RESOLVE **always** selects simulate; the "nothing written externally" invariant stays literally true (ADR-4 not crossed).

**2 — APPLY (write) [inert while `crm.write` unbound].** The Growth / Epic G path, authored now as
real procedure so activation is a binding flip, never a design task. Runs **only** when Step 1
positively confirmed `crm.write`:

- Push the field-level `crm_update` (stage recommendation, next step, product gaps) to the CRM via the logical `crm.write` capability — logical capability only, never a concrete CRM/tool identifier (ADR-6).
- Hand the object to `render.crm_update(crm_view)` with a **"synced"** confirmation in place of the "(simulated)" marker; cite what was written.
- This branch never executes while `crm.write` is unbound (see Failure rules — a write failure or unconfirmed resolution degrades to simulate, never an assumed write surface).

**3 — APPLY (simulate) [live path].** The verbatim current behavior — persist a local dated draft
and render it informationally. Persist mechanics moved unchanged from `work-account` Step 7:

- Write the `crm_update` object to `accounts|projects/<slug>/drafts/YYYY-MM-DD-crm-update.md`.
  - Date in the run's `timezone`, handled in-skill; create `drafts/` if missing; never repo root or `company/`.
  - The `.md` extension — `.yaml` is reserved for the tasks draft.
  - A same-date re-run overwrites the same-date file — latest synthesis wins, the same authority rule as the tasks draft.
- YAML frontmatter `{ namespace, slug, date, current_stage, recommendation }`, plus `to_stage` only when advancing.
- Markdown body: the three sections shaped as the field-level update a CRM would receive, headed by the "(simulated)" marker and an explicit nothing-was-sent-externally note. Unmet criteria render as "no evidence this run" — informational checkboxes, never `render.tasks`; the criteria block is omitted entirely on a `not-applicable` recommendation.

```markdown
---
namespace: accounts
slug: virgin-atlantic
date: 2026-06-12
current_stage: technical-validation
recommendation: no-change
---
# CRM Update (simulated) — virgin-atlantic — 2026-06-12

> What would be written to the CRM after this session. Nothing has been sent to any
> external system — apply manually if you agree.

## Stage
**Current:** technical-validation · **Recommendation: no change**
- [x] A pilot has hit its agreed success criteria — transcript: "the pilot hit the latency target we agreed on"
- [ ] Technical stakeholders have signed off that the platform meets their requirements — no evidence this run

## Next Step
Schedule the security-review session with their infra team.

## Product Gaps
- No native Okta SSO integration — email: "does the platform support Okta SSO out of the box?"
```

- Hand the object + persisted filename to `render.crm_update(crm_view)` — the interactive informational card on UI-capable runtimes, the plain in-chat **"CRM Updates (simulated)"** Markdown section otherwise (same fields on both). State plainly the persisted filename and that **nothing was written to any external system** — the rep applies the update to their real CRM manually if they agree.
- Informational only: no `review.collect` call, no verdict, no `capture-feedback` line — silence has no meaning here.

## Writes

- `accounts|projects/<slug>/drafts/YYYY-MM-DD-crm-update.md` — the simulated CRM update (the simulate branch only, Step 3); same-date re-run overwrites the same-date file. No write on the (inert) write branch touches any local draft; no external write occurs on either branch while `crm.write` is unbound.

## Failure rules

- `crm.write` unbound / resolution unconfirmed (the only live state today) → simulate branch; never assume a write surface.
- crm-update write failure (simulate branch) → surface it in chat, render the section from the in-memory `crm_update` object, and do **not** roll back the tasks YAML or block ENRICH (`work-account` Step 8), MARK PROCESSED (Step 9), or `run-unbound`'s `last_run` advance — the task plan is the run's primary artifact.
- generation failure (empty/absent `crm_update` object handed back) → replace the sub-beat with one honest close-out line ("no CRM update this run — <reason>"); never block close-out.
- Same-day re-run → overwrite the same-date `crm-update.md` (latest synthesis wins).
- No verdict surface → never enters `review.collect`, never writes `feedback-log.jsonl` (informational only).
- All writes are local; no external write ever while `crm.write` is unbound; name no concrete MCP/CRM tool — logical capabilities only (ADR-6).
