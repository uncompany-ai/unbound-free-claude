---
type: account
slug: brightwater-media
name: Brightwater Media Group
domains: [brightwatermedia.com]
stage: technical-validation
stakeholders:
  - { name: Lars Vandenberg, role: Revenue operations lead (sponsor), champion: true }
  - { name: Femke Janssen, role: Salesforce owner — three mastheads, one org each, champion: false }
  - { name: Yara Osei, role: Desk lead, national brands masthead, champion: false }
  - { name: Davey Brandt, role: Desk lead, regional and trade mastheads, champion: false }
  - { name: Sanne Vermeer, role: Program coordinator (books the working sessions), champion: false }
last_next_step: "Working session with the desk leads to walk the first drafts against real open deals, ahead of the in-person deep-dive."
open_questions: []
competitive_threats: []
created: 2026-06-12
updated: 2026-06-12
---

## Summary
Brightwater Media Group (advertising sales across three mastheads — national brands, regional, and trade) is in `technical-validation` under the internal name "Project Lighthouse". Thirty-one sellers work the desk out of three separate Salesforce orgs, one per masthead. Salesforce and the call recorder talk to each other; nothing else does, so Femke rebuilds the pipeline review by hand every Monday morning out of the three orgs, and the three stage fields the desk actually uses are wrong more often than they are right. Deals move between the call and the log: a rate-card conversation happens on Tuesday, the seller writes the follow-up that evening or the next morning, and the opportunity is logged Friday if it is logged at all — so nobody sees the movement until Monday. Every seller picked up an AI seat in the corporate rollout in March, which is where an installed agent would run: it reads the call and the thread, drafts the next move on each open deal, and the seller approves in one pass, with no new interface and no second login. Lars agreed on 2026-05-27 to evaluate hands-on rather than settle it by argument, which is what moved the deal to `technical-validation`. He is also the honest sceptic on the number — he half-believes the post-call admin is not costing what the sellers claim and wants that proved, so the evaluation turns on a baseline week measured on their own desk rather than on our slide. Femke gates the write side and needs the three org IDs and the stage-field mapping settled before anything touches Salesforce. The desk leads run the floor and have to see it work on real deals before Lars can call it. Grounded in the 2026-05-27 install-readiness review transcript.

## Activity Log

### 2026-06-12 — Processed 2026-05-27 install-readiness review
Worked the 2026-05-27 install-readiness review. Synthesized the task plan in `drafts/2026-06-12-tasks.yaml` (P1 recap-and-scope follow-up to Lars and Femke; P2 prepare the baseline-week measurement plan for the desk leads; P3 internal — settle the Salesforce write scope with Femke before the working session). Key facts: three mastheads, one Salesforce org each, thirty-one sellers; the Monday pipeline rebuild is manual; AI seats already rolled out in March, so the install adds no new interface; Lars wants the admin-minutes claim proved rather than asserted; the desk leads are the people who have to say yes. Follow-up email drafted and accepted at close-out (`drafts/2026-06-12-email.md`). CRM update simulated in `drafts/2026-06-12-crm-update.md`. Stage unchanged (`technical-validation`).
