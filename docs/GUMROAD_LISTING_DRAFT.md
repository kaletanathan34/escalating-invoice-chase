# DRAFT — Gumroad listing (do not publish)

> **STATUS: DRAFT ONLY.** Not published. Copy below is for review before any Gumroad create/publish step.

---

## Title

Escalating Invoice Chase — n8n + Google Sheets + Gmail AR Reminder Pack

## Subtitle

Stop manually chasing invoices. Auto-send polite → firm → final reminders on Day 0 / +3 / +7 — and stop when they’re marked Paid or the client replies STOP.

## Price

**$149** (USD)

## Positioning (one clear line)

This is **friendly AR / payment reminders** for invoices you already issued — **not** collections software, debt recovery, or legal action. If you need a collections agency or demand letters, this pack is the wrong product.

## Hero bullets

- **3-stage chase** tuned for freelancers: due-day polite, day-+3 firm, day-+7 final
- **Stops on Paid** — no awkward “please pay” after the wire clears
- **Reply STOP (or unsubscribe) halts reminders for that invoice** — remaining Day 0 / +3 / +7 sends are cancelled
- **No double-sends** — claim-before-send + cooldown so overlapping cron runs don’t spam clients
- **Your Gmail, your Sheet** — import the n8n workflows; connect OAuth; copy the CSV template
- **Least-privilege by design** — chase Gmail `send` scope only; no mailbox read in the main pack

## What’s included

1. Importable **n8n workflow** JSON — main chase (`workflows/invoice-chase.json`)
2. **STOP reply** workflow — pauses that invoice when the client replies STOP
3. Optional **signed unsubscribe webhook** workflow (shared-secret header)
4. **Google Sheets** column schema + sample CSV (`templates/invoices.sample.csv`)
5. Setup README (credentials, stages, STOP / opt-out, security)
6. Security / threat notes for careful operators
7. Credential scrub script for anyone mirroring the workflow in git

**Not included:** hosted n8n, Google Workspace, Gumroad-side OAuth, or done-for-you inbox setup. You run this in **your** n8n (Cloud or self-host) with **your** Google accounts.

**Paid DFY install** (we set it up in your n8n / Sheet for you) may be offered separately — it is **not** included in the $149 pack.

## Who it’s for

Freelancers and micro-agencies (roughly solo–5 people) who track invoices in a spreadsheet and send payment reminders from Gmail today by hand — and want a polite automated nudge, not a collections stack.

## Setup time

- **~20–40 minutes** if you already use n8n + Google OAuth  
- **~60–90 minutes** first-time (create credentials, dry-run to yourself, activate schedule + STOP handler)

## Stage schedule (what clients actually get)

| Day | Tone |
|-----|------|
| 0 (due date) | Polite reminder |
| +3 | Firm follow-up |
| +7 | Final notice |

Max **3** emails per open invoice. Mark Paid, or the client **replies STOP** / hits unsubscribe → reminders for that invoice halt (no further stages).

## FAQ (draft)

**Does this work with Stripe/Wave?**  
MVP reads Google Sheets. Stripe/Wave status sync is a future add-on — use read-only keys only; never put card PANs in Sheets.

**Will it spam my clients?**  
No: stage-capped; Paid stops the chase; **reply STOP or unsubscribe halts reminders for that invoice**; claim + cooldown against double-sends. You control the Sheet.

**Is this collections / legal demand software?**  
No. Friendly AR / payment reminders only — not collections, debt recovery, or legal action.

**Do you get my Gmail login?**  
No. OAuth stays in **your** n8n. This pack never ships buyer credentials.

**Is install included?**  
The $149 pack is DIY import + docs. Paid done-for-you install may be available separately — not included here.

## Compliance blurb (draft)

Transactional payment reminders for your own invoices. Honor Paid and client STOP / unsubscribe (halts further reminders for that invoice). Use your real business identity and reply address. Not a marketing blast tool and not a collections product.

---

*End of DRAFT — do not publish without product + security sign-off.*
