# Sales Process & Canonical Stage List

This file defines our **sales methodology** and the **canonical sales stage list** for
the Unbound agent.

> **This stage list is the authoritative `stage` enum.** Every account's
> `accounts/<account>/context.md` frontmatter `stage:` field **MUST** be one of the
> lowercase/kebab tokens defined below. Skills (`classify-work`, `bootstrap-context`,
> `work-account`) validate account stage values against this list by convention — an
> account stage that is not in this enum is an error to be flagged, not a new stage.
> Keep these tokens **stable**: renaming a token silently orphans every account already
> tagged with it.

We sell contextual rewiring: we extract how one revenue team actually sells and encode it
into workflows they own and run inside the AI seats they already pay for. There is one
install fee and no subscription, so a deal moves by proving the install is worth doing and
that it will still be running once we leave — not by expanding a footprint.

## Sales Stages (canonical enum)

Each stage below is a token usable verbatim as a `stage:` value, followed by a
definition and its entry/exit criteria. Stages are roughly sequential, but deals can
skip or revert; `stage:` always reflects the deal's *current* reality, not its history.

### `discovery`

**Definition:** We are learning how this team actually sells — what they run and what is
genuinely connected, how a deal moves and where it stalls, what is costing reps the most
time, and what would make this a clear yes. No install has been scoped. The goal is to
qualify fit and find the minutes an agent would give back.

- **Entry:** A qualified opportunity exists — there is an identified problem and an
  engaged contact willing to invest time.

**Exit criteria:**
- We can name the AI seat the team already has and the systems holding the raw record
- We can describe how a deal moves today and the point at which it falls out of view
- We can state the time cost in their words, not ours
- We can name at least one number the install would have to move

### `demo`

**Definition:** We are showing the loop running against their context — the agent reads
the call and the thread, drafts the next move, the rep approves — rather than a generic
walkthrough. The point being proved is that nothing new appears on the rep's screen.

- **Entry:** Discovery is complete; we have a use case and an audience that includes at
  least one person who feels the pain.

**Exit criteria:**
- The audience has watched the loop run on work that looks like theirs
- They have confirmed it addresses the problem, or named the gaps that must be closed first

### `technical-validation`

**Definition:** The people who gate the install are evaluating it hands-on — the security
and governance review, the approval path, what the agent can and cannot touch, and the
scope of a time-boxed install measured against a baseline week on their own desk.

- **Entry:** Business interest is established and a technical evaluation has been agreed.

**Exit criteria:**
- The people who gate the install have signed off — security, systems ownership, and the
  desk that will use it, OR
- A time-boxed install has met the success criteria agreed before it started

### `proposal`

**Definition:** We have put the install in writing — scope, the desks covered, the install
fee, and the measures it will be judged on — mapped to the numbers the buyer named in
discovery.

- **Entry:** Technical fit is established and the buyer has asked for commercial terms.

**Exit criteria:**
- The buyer is reviewing the proposal
- We have entered commercial discussion (or the proposal is declined)

### `negotiation`

**Definition:** We are working through commercial terms, the paper, procurement and
security sign-off, and the named re-engagement price for coming back when the way they
sell changes.

- **Entry:** The proposal is accepted in principle and we are resolving terms.

**Exit criteria:**
- Terms are agreed
- The contract is sent for signature (or the deal stalls / is lost)

### `closed-won`

**Definition:** The paper is signed and the install is booked. The account transitions to
the install itself, instrumented from day one.

- **Entry:** Signature received.

**Exit criteria:**
- Terminal state.

### `closed-lost`

**Definition:** The opportunity is no longer active — the prospect chose another path, a
competitor, or no decision (status quo).

- **Entry:** Buyer declines, goes dark beyond recovery, or selects an alternative.

**Exit criteria:**
- Terminal state. Capture the loss reason in the account's `context.md` for later
  re-engagement.

## Quick reference

| Stage token | One-line meaning |
| --- | --- |
| `discovery` | Learning how they sell, what is connected, where the time goes. |
| `demo` | Showing the loop run against their own context. |
| `technical-validation` | Approval path, governance review, scoped install on their desk. |
| `proposal` | Install scope + fee in writing, mapped to their numbers. |
| `negotiation` | Terms, paper, procurement, re-engagement pricing. |
| `closed-won` | Signed and booked; the install starts. |
| `closed-lost` | No longer active; capture loss reason. |

---

## Freshness & maintenance note

**Owner:** Nadia Ellis (rep). **Review cadence:** at the start of each quarter, or whenever
the sales process changes (new stage, renamed stage, changed entry/exit criteria).

This stage list is a **contract**, not documentation. Before renaming or removing a
token, search `accounts/*/context.md` for accounts already tagged with it — renaming a
token silently orphans every account that uses it. When you add a stage, add its
definition and entry/exit criteria here so the agent (and any teammate) can reason about
it. A stale or inconsistent stage list degrades classification and slate accuracy across
every account, so keep this current and self-consistent.
