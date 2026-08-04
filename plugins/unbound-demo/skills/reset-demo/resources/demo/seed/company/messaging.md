# Messaging & Voice

This file captures our **positioning**, **objection handling**, and **voice/tone**. It is
read by `work-account` (synthesis) and `draft-followup` (email drafting) so that every
follow-up and summary the agent produces sounds like us and stays on-message.

> Treat this as the source of truth for *how we talk about the product*. If a draft
> contradicts what's here, the draft is wrong.

## Positioning

**What we sell.** Contextual rewiring for revenue teams. We extract how a specific team
actually sells and encode it as human-approved workflows that run inside the AI seat the
team already has — the agent reads the raw record, drafts the next move, the rep approves.
One install fee, no subscription. The customer keeps the config.

**Who we sell to.** Revenue teams who already bought AI seats and have not converted them
into performance — seed-to-Series B desks running without a RevOps function, and mid-market
desks under a RevOps leader. The economic buyer is the VP or head of revenue operations,
sales, or the commercial function; the people who gate the install are security and
governance, whoever owns the CRM, and the desk leads whose reps have to open it.

**Core value proposition.** *The CRM is a compression artifact, and the compression is
failing.* It asks reps to hand-summarize calls and threads into fields at the end of the
day — low-value work they rightly skip — so the record decays into fiction and forecasting,
coaching and pipeline review run on the fiction. The raw record already exists in
machine-readable form. We put an agent on it, in the seat the rep already opens, and give
the rep back the hour after every call.

**Three pillars (how we differentiate):**

1. **We are the rewiring layer, not another product.** SaaS vendors cannot occupy it,
   CRM incumbents will not, and platforms build capability rather than company-specific
   deployments. What we deliver is your way of working, encoded — not a tool to adopt.
2. **No rent, not no relationship.** One install fee, no subscription, no lock-in. You pay
   the AI provider direct, at source. Re-engagement — extract, redeploy as the way you sell
   changes — is a named, openly priced motion rather than a renewal you cannot refuse.
3. **Draft-and-approve, always.** A human approves every action, in one pass. The agent
   brings no logins of its own and opens no connections of its own; it reads through the
   access the seat already has, and it never sends. We do not sell autonomy.

**Proof points to lean on:** admin minutes reclaimed per rep per day measured against a
baseline week on their own desk; approval rate and edits-before-approval on the drafts the
agent writes; enquiry and follow-up turnaround; and the one that settles it — installs
still running unattended two quarters later, because durability without us is the whole
thesis.

## Objection handling

**"We already have AI seats / we tried this and nothing changed."**
Agree, and name why. AI layered on an unchanged workflow just automates the complexity;
the value shows up when the workflow itself is rewired end to end. Ask what a rep actually
does in the hour after a call today, then offer to measure a baseline week before anything
goes live.

**"How do I know the time saving is real?"**
Do not assert it. Fix a baseline week first, count the admin minutes per rep, then count
approval rate and minutes reclaimed across the first live week and put the two side by
side. Agree what gets counted before anyone starts, so nobody moves the goalposts after.

**"Security and governance will not approve another vendor."**
It is not another vendor in their stack. The agent adds no new logins and opens no new
connections — it reads through the access the AI seat already has, drafts, and stops. Bring
security into `technical-validation` early with the ownership overview rather than meeting
them as a late gate.

**"What does it cost, and what happens in year two?"**
One install fee covers the install. There is no subscription and no rent on the workflow,
and the config is a set of files they keep. Re-engagement is priced and named up front, so
the answer to "what does this cost" covers the whole relationship, not just the first
invoice.

**"What happens when you leave?"**
That is the test we want to be judged on. The engagement closes when the install closes,
and the install is instrumented from day one so both sides can see whether the workflow is
still running unattended months later. If it is not, we were wrong.

**"Now isn't the right time."**
Find the trigger. "Now" usually becomes now when a quarter misses on forecast accuracy, an
AI rollout has to justify its budget, or a new leader arrives with a mandate. Anchor the
next step to their event, not our quarter.

## Voice & tone

**We sound like:** an operator talking to another operator — plainspoken, short, and
specific. State the math instead of selling the dream.

**Do:**
- Lead with what it costs them today, in their words, before anything we do.
- Be specific and quantified ("ninety minutes per rep per day, measured"), not vague.
- Keep follow-ups short and skimmable — a busy buyer reads them between meetings.
- Reference what *they* actually said on the call; ground every claim in evidence.
- Attach a consequence to every capability. A feature with no consequence does not go in.

**Don't:**
- Use hype or superlatives ("revolutionary," "best-in-class," "game-changing").
- Over-promise or invent metrics we did not establish together.
- Promise autonomy, or imply anything sends without a human approving it.
- Bury the ask — every follow-up has one clear, easy next step.
- Send a wall of text or a generic template that ignores the conversation.
- Use emoji. Ever.

**Default follow-up shape:** warm one-line opener that references the call → a 2–4 bullet
recap of what we agreed/what matters → one clear next step with a proposed time → optional
single relevant asset link. Sign off plainly.

---

## Freshness & maintenance note

**Owner:** Nadia Ellis (rep). **Review cadence:** each quarter, and whenever positioning,
pricing, the competitive picture, or our differentiators change (a new common objection
from the field, a change to the install fee or the re-engagement price, a messaging
refresh).

Drafts generated by `draft-followup` inherit their voice and claims from this file. If
this goes stale, every generated email drifts off-message — so update objection handling
when the field hears a new one, and update proof points when the numbers change. When you
revise positioning, sanity-check that `assets.md` still maps assets to the use cases and
pain points described here.
