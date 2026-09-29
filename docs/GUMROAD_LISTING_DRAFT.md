# DRAFT — Gumroad listing (do not publish)

> **STATUS: DRAFT ONLY.** Not published. Copy below is for review before any Gumroad create/publish step.

---

## Title

Escalating Invoice Chase — n8n + Google Sheets + Gmail AR Reminder Pack

## Subtitle

Stop manually chasing invoices. Auto-send polite → firm → final reminders on Day 0 / +3 / +7 — and stop the second they’re marked Paid.

## Price

**$149** (USD)

## Hero bullets

- **3-stage chase** tuned for freelancers: due-day polite, day-+3 firm, day-+7 final
- **Stops on Paid** (and Paused) — no awkward “please pay” after the wire clears
- **No double-sends** — claim-before-send + cooldown so overlapping cron runs don’t spam clients
- **Your Gmail, your Sheet** — import one n8n workflow; connect OAuth; copy the CSV template
- **Least-privilege by design** — Gmail `send` scope only; no mailbox read in the pack

## What’s included

1. Importable **n8n workflow** JSON (`workflows/invoice-chase.json`)
2. **Google Sheets** column schema + sample CSV (`templates/invoices.sample.csv`)
3. Setup README (credentials, stages, security)
4. Security / threat notes for careful operators
5. Credential scrub script for anyone mirroring the workflow in git

**Not included:** hosted n8n, Google Workspace, Gumroad-side OAuth, or done-for-you inbox setup. You run this in **your** n8n (Cloud or self-host) with **your** Google accounts.

## Who it’s for

Freelancers and micro-agencies (roughly solo–5 people) who track invoices in a spreadsheet and send reminders from Gmail today by hand.

## Setup time

- **~20–40 minutes** if you already use n8n + Google OAuth  
- **~60–90 minutes** first-time (create credentials, dry-run to yourself, activate schedule)

## Stage schedule (what clients actually get)

| Day | Tone |
|-----|------|
| 0 (due date) | Polite reminder |
| +3 | Firm follow-up |
| +7 | Final notice |

Max **3** emails per open invoice. Mark `Paid` → chase stops.

## FAQ (draft)

**Does this work with Stripe/Wave?**  
MVP reads Google Sheets. Stripe/Wave status sync is a future add-on — use read-only keys only; never put card PANs in Sheets.

**Will it spam my clients?**  
No: stage-capped, Paid/Paused stop, claim + cooldown against double-sends. You control the Sheet.

**Do you get my Gmail login?**  
No. OAuth stays in **your** n8n. This pack never ships buyer credentials.

## Compliance blurb (draft)

Transactional payment reminders for your own invoices. Honor Paid and opt-out (`Paused`). Use your real business identity and reply address. Not a marketing blast tool.

---

*End of DRAFT — do not publish without product + security sign-off.*
