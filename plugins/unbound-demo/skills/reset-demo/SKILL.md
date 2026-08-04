---
name: reset-demo
description: Demo workspace bootstrap and reset. A standalone, rep-invocable skill that runs the bundled reset script to seed an empty demo workspace from its pristine snapshot, or restore a used one to that same state through the same single command. Invoked directly by the presenter ("reset the demo", "set up a fresh demo workspace", "put the demo back before the next showing", "show me what a reset would change") — never auto-run by the run loop.
tier: demo
---
# reset-demo

Standalone, presenter-invoked demo workspace reset. It locates the bundled reset script, selects a
mode from the presenter's intent, runs the script against the current working directory, and
relays the result verbatim. Seeding an empty workspace and restoring a used one are the same
command in the same mode.

## Reads

- The reset script — `resources/reset-demo.sh` beside this skill's bundled resources, or `runtime/demo/reset-demo.sh` in a corpus checkout.
- The seed snapshot — resolved by the script from its own location; this skill never locates, reads or names its files.
- The presenter's stated intent — the only input that selects a mode.

## Procedure

**1 — Locate the script.** Take `resources/reset-demo.sh` beside this skill's bundled resources
when it exists, otherwise `runtime/demo/reset-demo.sh` in a corpus checkout.

**2 — Select the mode from the presenter's intent.**

- "reset the demo", "start over", "set up a fresh workspace", "seed an empty folder" → no flags, the full reset — the default whenever intent is unqualified.
- "show me what it would change", "preview it first", "is it safe" → `--check`, which prints the plan and writes nothing.
- "just reset the clock", "re-show the same slate" → `--state-only`, which restores the run state alone and removes no drafts.
- A preview of the narrow mode → `--check` and `--state-only` together, in either order.

**3 — Run the script from the demo workspace.** Invoke it with the selected flags while the
working directory is the presenter's disposable demo workspace folder.

**4 — Relay the output verbatim.** Surface the header, the restore list, the remove list and the
closing line exactly as printed — terse, no embellishment, no summary standing in for the plan.

**5 — Stop on a non-zero exit.**

- Report the script's message as-is, adding no diagnosis and no correction.
- Repair nothing by hand — leave the workspace exactly as the script left it.
- Wait for the presenter's direction before running anything further.

## Writes

- Nothing directly — every write is the script's.
- Restored: the run state, the feedback log, the company context, and each account's context file and seeded drafts.
- Deleted: run-generated draft files the seed snapshot does not contain, and nothing else.

## Invariants

- Idempotent: a second consecutive run leaves the workspace byte-identical.
- Account folders are never deleted — each folder, its context file and its seeded drafts survive every run.
- Nothing outside the presenter's working directory is ever written.
- A working directory holding both `skills/` and `runtime/` is a corpus checkout, and the script refuses it — relay that refusal, never work around it.
- No external call is made and no credential is needed.
- Never auto-run inside the `run-unbound` loop — the presenter invokes it directly, between showings.

---

## Bundled resources (Cowork)

> This is the **standalone** Cowork build of reset-demo. The reset script ships in this same skill
> folder as `resources/reset-demo.sh`, and the pristine workspace snapshot it restores ships beside
> it as `resources/demo/seed/`. Run the bundled script — do not expect a `runtime/` tree, and do not
> locate or read the seed files yourself; the script resolves them from its own location.
>
> **The reset targets the project working directory Cowork is operating in — never this skill
> folder.** The script writes `state/`, `company/` and `accounts|projects/` under that working
> directory, and refuses to run against an Unbound corpus checkout. `resources/demo/seed/` is the
> read-only source it copies FROM; nothing is ever written back into it.
