# Asset Index

This is the index of sales/marketing assets the agent can recommend. It is the
**first-pass asset matcher** read by `draft-followup` (Epic 4): given a deal's `stage` and
a stated pain point, the agent looks here first, then verifies the link against Drive.

**Table shape (fixed):** one row per asset, columns
`Asset | Vertical | Use case | Stage | Pain point | Link`.

> **Stage values draw from the canonical enum** in `company/process.md`
> (`discovery`, `demo`, `technical-validation`, `proposal`, `negotiation`,
> `closed-won`, `closed-lost`). Use `any` when an asset is stage-agnostic. Do not invent
> stage tokens here — an orphan stage value breaks matching.

| Asset | Vertical | Use case | Stage | Pain point | Link |
| --- | --- | --- | --- | --- | --- |
| Revenue Rewiring Diagnostic (1-pager) | Any | Showing a revenue leader where the selling week actually goes and which workflows are worth rewiring first | `discovery` | "We bought the seats and nothing changed — I can't say which part of the week we'd get back" | https://drive.google.com/file/d/1QN7fK3rVbT2sxJm9dLuPzA4eHgW0Cyv/view |
| Recorded Walkthrough — Agents in the AI Seat | Retail | Showing the whole loop uncut — the agent reads the call, writes the slate, the seller approves | `demo` | "Is this another interface my floor has to learn? And who approves what it writes?" | https://drive.google.com/file/d/1TzR5mB8kXqLcW2vNfJ4hPdS7yG1oEua/view |
| Approval-Rate & Minutes-Reclaimed Worksheet | Any | Fixing the baseline week and what gets counted, so the time saved is measured rather than asserted | `technical-validation` | "I half-believe the admin time isn't costing us what they claim — you'd have to show me it is" | https://drive.google.com/file/d/1MwH9pZ6tKrNvB3xQjD5fLcY8sV2nAeT/view |
| Security & Ownership Overview | Financial Services | Answering the governance review: no new logins, no new connections, drafts but never sends | `technical-validation` | "Something reads a client thread and then sends — show me where the approval sits and who holds the keys" | https://drive.google.com/file/d/1BdX4nR7yWqTmJ2kPvL9cHzF6gS3uNoi/view |
| Durability Proof — Still Running Six Months On | Travel / Hospitality | Peer proof for an exec review — a comparable desk still running the workflow unattended, with the measured numbers | `proposal` | "Our own projections carry nothing at this stage — I need something I can put in front of the exec review" | https://drive.google.com/file/d/1LfC8vJ3hQbXsK5wRtM7pZyN2dG4aVer/view |
| Three-Day Install Scope & Success Criteria | Any | Time-boxing the install with pass and fail criteria agreed before day one | `technical-validation` | "We've sat through a six-month rollout before and we assume this is another one" | https://drive.google.com/file/d/1PsK6qY2mNdVrJ9tXfB4zHcW7uL3gAoi/view |
| Install Fee & Re-engagement Pricing Guide | Any | Stating the whole commercial relationship: what the install fee covers, what a second team adds, how re-engagement is priced | `negotiation` | "Procurement will ask for the year-two number and I want to say zero rent and mean it" | https://drive.google.com/file/d/1XvT3jL9wRbQnM6yKpF2sDzC8hV5oGua/view |

> The seven rows above are the collateral set as published today, and they mirror the shared
> Drive folder one row per file. Keep the two in step: when an asset is created, renamed,
> moved, or retired in Drive, make the same edit here in the same sitting, because
> `draft-followup` matches on this table first and only then verifies the link. An asset that
> exists in Drive but not here is never recommended; a row here with no file behind it makes
> the agent recommend nothing rather than guess.

---

## Freshness & maintenance note

**Owner:** Nadia Ellis (rep). **Review cadence:** monthly, and whenever an asset is created,
renamed, moved, or retired in Drive.

This index is a cache of pointers, so it goes stale faster than the other `company/`
files: links break when files move, assets get superseded, and new collateral lands
between reviews. Stale entries silently degrade `draft-followup`'s recommendations — the
agent will confidently suggest a dead link or an outdated deck. To keep it healthy:

- Verify each `Link` resolves; remove or fix dead links promptly.
- When you add an asset, fill in **all** columns — especially `Stage` (must be a token
  from `process.md`) and `Pain point` (in the customer's words), since those drive
  matching quality.
- Keep `Use case` and `Pain point` aligned with the positioning in `messaging.md`.
