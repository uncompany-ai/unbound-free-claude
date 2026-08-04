# Security & Ownership Overview

**Drive ref:** drv_security_architecture · **Stage:** technical-validation · **Vertical:** Financial Services

What a security and governance review needs, on one read: the agent brings no logins of its own,
opens no connections of its own, and drafts without ever sending. For deals where compliance
would otherwise arrive as a late gate, and where someone senior wants to know who holds the keys.

- No new logins and no new connections — it reads through the access the AI seat already has.
- Draft-and-approve is the whole design, so nothing ships without one human approval, in one pass.
- The config is a set of files you own and keep; the engagement closes when the install closes.

> Demo fixture body. Verifies the `content.get` read for the security and ownership asset.
