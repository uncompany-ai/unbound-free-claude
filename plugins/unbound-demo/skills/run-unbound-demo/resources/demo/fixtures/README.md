# Demo fixtures

These files are the **deterministic local data** that the demo runtime reads instead of live
connectors. The six external logical capabilities resolve to `Read`s of the files below; the
per-capability resolution lives in `runtime/demo/tool-bindings.md`, which is the only place
that mapping is written down. Nothing here is fetched over a network and nothing is ever
written — these files are **read-only** (ADR-4). The skills under `skills/` are unchanged and
remain blind to the fact that these are fixtures (ADR-6): they call only logical capability
names.

> **Determinism.** Every timestamp is full ISO-8601 **with offset** in `America/New_York` (the
> run `timezone`). Calendar `start`s and email `last_message_at`s are all **strictly after** the
> demo anchor `state/run-state.yaml` `last_run` (`2026-06-18T18:00:00-04:00`) and sit inside the
> last ten days of June 2026, so a fresh `/run-unbound-demo` with `scan_window: now` discovers the
> full intended slate. Discovery is since-`last_run`, so the dataset keeps working as real-world
> time passes — do **not** re-date it. There is no `Date.now()`-style nondeterminism: the data is
> fixed and byte-stable across resets.

## What a fresh `/run-unbound-demo` discovers (the seeded slate)

With the queue reset to empty and the anchor above, fixture discovery produces a 5-item slate
spanning every discover/fetch/classify branch. **This table is the acceptance contract**: a
rehearsal passes when the rendered slate matches these five rows.

| Item (slug) | Source(s) | Transcript | Notes |
| --- | --- | --- | --- |
| `brightwater-media` | call | **present** (granola) | The end-to-end **walk target** — synthesizes a P1 `followup_email`; MATCH-ASSET resolves to the Approval-Rate & Minutes-Reclaimed Worksheet (`drv_match_rate_worksheet`) on the transcript's baseline-week and admin-minutes language; the call closes on a meeting ask, so the next step drives AVAILABILITY. |
| `marlin-bay-cruises` | call | present (granola) | Second present-transcript call (proposal stage). The stated ask is peer proof for an exec review, which matches Durability Proof — Still Running Six Months On (`drv_travel_roi_casestudy`). |
| `halvorsen-pike` | call | present (granola) | Third present-transcript call (technical-validation). The stated ask is the approval path and who holds the keys, which matches the Security & Ownership Overview (`drv_security_architecture`). |
| `calla-vale` | email | n/a (email body is the evidence) | **Email-only** item; domain-matched (`callavale.com`) → `suggested_slug`. The sender asks what the install fee covers for a second team and how re-engagement is priced, which matches the Install Fee & Re-engagement Pricing Guide (`drv_pricing_packaging`). |
| `goldspire-resorts` | call + email | call leg **missing** | **Collapsed call+email same-slug** — both signals land on one queue row; the call leg is the required `transcript: missing` (surfaced-gap) branch and no body file exists for it **by design**; email domain-matched (`goldspireresorts.com`). |

All five slugs are pre-seeded with `accounts/<slug>/context.md` in the demo workspace seed, so
`bootstrap-context` is a **no-op** on every item — the demo creates no new context files and is
fully repeatable.

## The story this corpus tells

Every human-readable string here tells one story, and it is the current one. UnCompany installs
AI revenue agents inside the AI seat the reps already use — Claude, Copilot, ChatGPT — the agent
reads the raw record from the systems they already run, drafts the next move, and the rep
approves. One install fee; the customer pays the AI provider direct, at source; the engagement
closes when the install closes and the customer keeps the config. Nothing in this dataset adds a
tool to the buyer's stack. Each account's narrative takes one out.

The three call transcripts are shaped by the four pre-demo discovery questions, genuinely asked
and answered: what they are running today and what is really connected; how a deal actually
moves and where it gets stuck; what is costing the reps the most time; and what would make this
a clear yes, including who else has to see it happen. Each call then lands one named objection,
one asset the collateral answers with, and one next step.

The rep in this dataset is a fictional UnCompany persona, **Nadia Ellis**
(`nadia@uncompany.ai`), used identically in `calendar/events.json`, `email/threads.json`,
`calendar/freebusy.json` (as the map key) and every transcript header and speaker label. Every
prospect, company, and domain is fictional too. No real person's contact details, no real
customer's words, and no verbatim line from any real call appear anywhere in this tree.

## File shapes

### `calendar/events.json` — `calendar.list_events_since(ts)`
Array of calendar events. The binding returns those with `start` strictly after `ts`
(compared in the run `timezone`, per `discover-events` Step 2).
```json
{ "title": "…", "start": "<ISO 8601 ±hh:mm>", "end": "<ISO 8601 ±hh:mm>",
  "attendees": [ { "name": "…", "email": "…" } ], "ref": "cal_<slug>_<yyyymmdd>" }
```
- `ref` is the opaque correlation key carried forward to `transcript.get`.
- `attendees[].email` domains should match the account so `classify-work` reuses the seeded slug.

### `email/threads.json` — `email.list_unanswered_threads(ts)`
Array of **already post–hard-filter** inbound threads (INBOX-only, rep-not-last — that filter
is baked into authoring, so the skill never re-applies it). The binding returns those with
`last_message_at` strictly after `ts`.
```json
{ "thread_ref": "thr_<slug>_<yyyymmdd>", "subject": "…",
  "participants": [ { "name": "…", "email": "…" } ],
  "last_message_at": "<ISO 8601 ±hh:mm>",
  "latest_external_message_body": "…verbatim body…" }
```
- The external sender's email **domain** drives `discover-events` prospect matching → it must
  appear in the target account's `context.md` `domains:` list for a deterministic
  `suggested_slug` (or be a confident fuzzy name match).

### `transcripts/index.json` + `transcripts/<call_ref>.md` — `transcript.get(call_ref)`
A map from a calendar `ref` to its transcript location + provider, or a `missing` sentinel.
```json
{ "cal_brightwater_20260622": { "transcript_file": "transcripts/cal_brightwater_20260622.md", "provider": "granola" },
  "cal_goldspire_20260621": { "missing": true } }
```
- On a hit: the binding `Read`s `transcript_file` and returns `{ text, provider }`.
- On `missing` (or no entry): returns `missing` → `fetch-transcript` marks `transcript: missing`.
- `provider` is a verbatim kebab key (`granola` / `zoom` / `gong`), carried through unchanged.
- Three bodies exist (brightwater, marlinbay, halvorsen). The goldspire body is **deliberately
  absent** — that absence is the surfaced-gap fixture, so never author it.

### `drive/index.json` + `drive/<ref>.md` — `content.search(query)` / `content.get(ref)`
An index of assets that mirrors `company/assets.md`, plus one body file per asset.
```json
{ "ref": "drv_match_rate_worksheet", "name": "Approval-Rate & Minutes-Reclaimed Worksheet",
  "terms": ["approval rate", "minutes reclaimed", "baseline week", "technical-validation"] }
```
- `content.search(query)` returns the `ref`s whose `name`/`terms` match the query
  (case-insensitive substring) — `draft-followup` MATCH-ASSET searches by the asset's identity +
  stage/pain terms.
- `content.get(ref)` returns the contents of `drive/<ref>.md`; an **absent** file → not-found →
  the honest `none` MATCH-ASSET outcome.
- All 7 `assets.md` rows are mirrored here so whichever item the rep walks, its asset verifies.
- The `drv_*` keys are opaque correlation keys and are never shown to an audience; some of them
  predate the current asset names, so read the `name` field, not the key.
- The last entry in every `terms` array is a stage token from the `company/process.md` enum.

### `calendar/freebusy.json` — `calendar.availability(attendees, window)`
A map from attendee email → array of **busy** blocks. The binding derives **open** slots =
`window` minus busy, in-skill, in the run `timezone`.
```json
{ "nadia@uncompany.ai": [ { "start": "<ISO>", "end": "<ISO>" }, … ] }
```
- The seeded next-step dates are in the past relative to "now", so `draft-followup`
  AVAILABILITY falls through to its default **coming-two-weeks** window — these busy blocks cover
  `2026-06-29 → 2026-07-11` and leave common open windows so 2–3 candidate slots are derived.
- An attendee **absent** from this file is "unreadable" → `draft-followup` Step 3 degrades to the
  readable attendees (at minimum the rep) and phrases slots as offers — never guesses.

## How to extend

1. **Add a discoverable item:** append an event to `calendar/events.json` and/or a thread to
   `email/threads.json` with a `start`/`last_message_at` strictly after the anchor. For a call,
   add a `transcripts/index.json` entry (present → also add the `<call_ref>.md` body; or `missing`).
2. **Make it route to an account:** ensure `accounts/<slug>/context.md` exists in the seed and,
   for emails, that the sender domain is in its `domains:` list.
3. **Make a follow-up reference an asset:** ensure the asset row exists in `company/assets.md` and
   is mirrored in `drive/index.json` (+ a `drive/<ref>.md` body) with matching `terms`.
4. **Meeting slots:** add the required attendees' emails to `calendar/freebusy.json` with busy
   blocks inside the window, leaving common gaps.
5. **Re-anchor if needed:** if you move `last_run`, re-check every timestamp is strictly after it.
6. **Keep the narrative current:** hold every new string to the same story as the section above —
   the agent runs inside the seat the rep already has, reads the raw record, drafts the next move,
   and the rep approves; one install fee, no rent, the customer keeps the config. Plainspoken and
   short. State the math instead of selling the outcome, and never write a feature with no
   consequence attached to it.
7. **Update this table:** any change to the five items above changes the acceptance contract, so
   edit the seeded-slate table in the same commit.
8. Validate: every `*.json` must parse as JSON (a malformed fixture surfaces as a read failure),
   and every `transcript_file` and `drv_*` ref must resolve to a file on disk.
