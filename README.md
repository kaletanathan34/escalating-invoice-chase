# Escalating Invoice Chase (n8n + Google Sheets + Gmail)

**Ship your AR reminders on autopilot.** A ready-to-import n8n workflow that sends escalating payment reminders at **Day 0 (due) / Day +3 / Day +7** relative to each invoice due date — and **stops when marked Paid, or when the client replies STOP** (sets Paused; remaining stages cancelled).

Built for freelancers and micro-agencies who are tired of chasing invoices by hand.

## Buy / store

**Live pack ($149):** [https://kaletana.gumroad.com/l/vnhyc](https://kaletana.gumroad.com/l/vnhyc)

GitHub is the public scaffold and docs mirror. Buyers: get the pack on Gumroad, then follow Setup below.

---

## Who it's for

- Freelancers and 1–5 person agencies
- Anyone tracking invoices in Google Sheets (Wave/Stripe status sync can come later)
- People who want polite → firm → final reminders without babysitting a CRM

**Not** for: bulk marketing, cold email, or anything that needs a full ESP. This pack sends transactional payment reminders from **your own authenticated Gmail**.

---

## What's included

| Path | Purpose |
|------|---------|
| `workflows/invoice-chase.json` | Main chase: stages 0 / +3 / +7 (MVP) |
| `workflows/invoice-chase-stop-reply.json` | Reply-STOP handler → sets `Status=Paused` |
| `workflows/invoice-chase-unsubscribe-webhook.json` | Optional signed unsubscribe webhook → `Paused` |
| `workflows/invoice-chase-send-error.json` | Error Workflow stub: on failure → best-effort `Paused` + Notes |
| `templates/invoices.sample.csv` | Sheet column schema + sample rows (incl. Paid + Paused) |
| `docs/GUMROAD_LISTING_DRAFT.md` | Gumroad listing copy (live at $149) |
| `docs/THREAT_NOTES.md` | Security review notes |
| `scripts/scrub-credentials.sh` | Pre-commit / CI guard: fails if credential tokens sneak into the tree |
| `.githooks/pre-commit` | Optional local hook that runs the scrub script |
| `docs/ci/scrub.yml` | GitHub Actions scrub workflow (copy to `.github/workflows/scrub.yml` to enable CI) |
| `LICENSE` | MIT |

---

## Technical specs

| Piece | Detail |
|-------|--------|
| Orchestration | n8n workflow (designed for n8n 1.x-style nodes) |
| Source of truth | Google Sheets (one row per invoice) |
| Delivery | Gmail via OAuth2 (`gmail.send` only) |
| Trigger | Schedule (default: every hour) |
| Stages (MVP) | **0** (due day, polite) → **3** (day +3, firm) → **7** (day +7, final) |
| Stop conditions | `Status = Paid` or `Paused`; Notes matching `\bSTOP\b`; never re-send same stage |
| Idempotency | Keyed by `InvoiceID` + stage; claim-before-send + cooldown; workflow **concurrency=1** |
| Send failure | Gmail error → Revert Claim (clear stage/timestamp + append timestamped error note); Error Workflow stub may set `Paused` |

---

## Sheet column schema

Import `templates/invoices.sample.csv` into a Google Sheet (or copy headers exactly).

| Column | Type / values | Notes |
|--------|----------------|-------|
| `InvoiceID` | string | Unique id (e.g. `INV-1001`). Part of idempotency key. |
| `ClientName` | string | Used in templates (HTML-escaped in workflow). |
| `ClientEmail` | email | Recipient. Must be a real address you are authorized to email. |
| `Amount` | number | Invoice amount (display only in email). |
| `Currency` | string | e.g. `USD` |
| `DueDate` | `YYYY-MM-DD` | Anchor for stage math. |
| `Status` | `Open` \| `Paid` \| `Paused` | `Paid` / `Paused` → skip forever (until you reopen). |
| `LastStageSent` | `none` \| `0` \| `3` \| `7` | Last stage successfully claimed/sent. |
| `LastSentAt` | ISO-8601 or empty | Timestamp of last claim/send. |
| `Notes` | string | Freeform; not emailed by default. |
| `FromName` | string | Display name in Gmail send (authenticated account still owns From). |
| `ReplyTo` | email | Optional reply-to override. |

**Authz boundary:** Treat the Sheet as a privileged control plane. Share it only with the **owner** and the **n8n Google identity** (OAuth user or service account). Anyone with edit access can change `ClientEmail`, `Status`, or amounts and weaponize outbound mail — see [Security notes](#security-notes).

---

## Stage schedule (MVP)

Stages are computed from calendar days overdue: `today − DueDate` (UTC date of due date vs run date).

| Stage key (`LastStageSent`) | When | Tone |
|-----------------------------|------|------|
| `0` | Due day (days overdue ≥ 0) | Polite reminder |
| `3` | 3 days after due (days overdue ≥ 3) | Firm follow-up |
| `7` | 7 days after due (days overdue ≥ 7) | Final notice |

**Stage cap:** max **3** stages per invoice in this MVP pack.

Rules:

1. Only one stage is eligible per run — the next unsent stage whose day threshold has been reached.
2. Order: `0` → `3` → `7`. Catch-up sends at most one stage per run after a successful claim.
3. If `Status` is `Paid` or `Paused`, skip entirely.
4. Stored values for `LastStageSent`: `none` | `0` | `3` | `7`.

---

## Stop-on-Paid + cooldown / idempotency

### Stop-on-Paid / STOP opt-out (mandatory product control)

**STOP is a product control, not a nice-to-have.** Flipping a row to `Status = Paused` (or `Paid`) cancels any remaining Day 0 / +3 / +7 sends because the main workflow **Compute Stage** skips those statuses.

| Path | What happens |
|------|----------------|
| Mark `Paid` | Settled — chase skips the row forever (until you reopen). |
| Client replies **STOP** | Import `workflows/invoice-chase-stop-reply.json`. On STOP (word boundary, case-insensitive) in subject/body: parse `InvoiceID` if present, else match `ClientEmail` + `Open` → set **`Status = Paused`**, append `[timestamp] STOP received` to `Notes`. |
| Signed unsubscribe webhook | Optional: `workflows/invoice-chase-unsubscribe-webhook.json`. `POST` `{ "invoiceId": "..." }` with header **`X-Chase-Secret`** matching n8n env `CHASE_UNSUBSCRIBE_SECRET` → `Status = Paused`. Wrong/missing secret → reject (401). **Never commit the real secret.** |

All stage email footers tell the client: *Reply STOP to this email to pause reminders for this invoice.*

**Defense-in-depth in Compute Stage:** even if Status is still `Open`, a `Notes` value matching word-boundary **STOP** (`\bSTOP\b`, case-insensitive) skips the row (same effect as Paused). Prefer the reply-STOP / webhook workflows that normalize to `Status=Paused`.

- Mark invoices `Paid` as soon as payment clears (manual or future Wave/Stripe sync).
- You can also set `Paused` manually in the Sheet for the same effect.

### Race on overlapping cron runs (claim-before-send)

n8n schedule triggers can overlap if a previous run is slow. **Double-send risk:** two runs both read `LastStageSent = none`, both decide to send stage `0`.

**Chosen pattern — claim row first, then send:**

1. Read rows.
2. Decide eligible stage (if any).
3. **Write** `LastStageSent` = that stage and `LastSentAt` = now **before** calling Gmail (claim / lock).
4. Send Gmail.
5. On Gmail send failure, `onError` routes to **Revert Claim**, which clears `LastStageSent` / `LastSentAt` and appends a timestamped error note to `Notes` so the stage can retry.

Also:

- **Cooldown:** skip if `LastSentAt` is within the last **55 minutes** (prevents hammering even if claim is stale).
- **Idempotency key:** `InvoiceID` + stage string; never send the same stage twice once claimed.
- **Concurrency:** main workflow settings `concurrency: 1` to reduce claim TOCTOU from overlapping executions.
- **Send failure:** Gmail node `onError` → **Revert Claim** (clears `LastStageSent` / `LastSentAt`, appends a timestamped error note to `Notes`) so the stage can retry. Pair `workflows/invoice-chase-send-error.json` as the Error Workflow for broader failures (best-effort `Status=Paused`).

---

## Architecture overview

```
Schedule Trigger (hourly)
        │
        ▼
 Google Sheets: Read invoice rows
        │
        ▼
 Code: compute stage (0/3/7), skip Paid/Paused, cooldown, pick next stage
        │
        ▼
 IF: has eligible stage?
        │ yes
        ▼
 Google Sheets: CLAIM — write LastStageSent + LastSentAt  ← before send
        │
        ▼
 Code: build escaped subject/body for stage (0 polite / 3 firm / 7 final)
        │
        ▼
 Gmail: send (oauth gmail.send only)
        │
        ▼
 (optional) Sheets: append send log / clear transient errors
```

**Optional webhook:** `workflows/invoice-chase-unsubscribe-webhook.json` requires header **`X-Chase-Secret`** (env `CHASE_UNSUBSCRIBE_SECRET`) and rejects unauthenticated calls. Main chase remains schedule-only.

---

## Env / credential vars (n8n)

Configure inside n8n — **never commit tokens**.

| Credential (placeholder name in export) | Type | Scopes / notes |
|-----------------------------------------|------|----------------|
| `Google Sheets account` | Google Sheets OAuth2 | Spreadsheet access for the **one** chase sheet only where possible |
| `Gmail account` | Gmail OAuth2 | Main chase: **`https://www.googleapis.com/auth/gmail.send` ONLY**. STOP-reply workflow needs read/poll scope on a **separate** credential when possible |
| `CHASE_UNSUBSCRIBE_SECRET` | n8n env var | Shared secret for `X-Chase-Secret` on the optional unsubscribe webhook — **never commit the real value** |

Exact Gmail scope for this pack:

```text
https://www.googleapis.com/auth/gmail.send
```

Workflow JSON in this repo uses **credential name references only** (empty / placeholder). No `access_token`, `refresh_token`, `client_secret`, or `private_key` values are stored.

Before every commit, run:

```bash
./scripts/scrub-credentials.sh
```

Or enable the sample hook:

```bash
git config core.hooksPath .githooks
```

To enable GitHub Actions scrub on PRs, copy `docs/ci/scrub.yml` → `.github/workflows/scrub.yml` (requires a token/app with the `workflow` scope to push that path).

---

## Setup steps

1. **Copy the sheet template**  
   Upload `templates/invoices.sample.csv` to Google Drive → Open with Google Sheets. Keep your real client data private.

2. **Import workflows**  
   n8n → Workflows → Import from File → `workflows/invoice-chase.json` (required).  
   Also import `workflows/invoice-chase-stop-reply.json` (STOP replies), optionally `workflows/invoice-chase-unsubscribe-webhook.json`, and `workflows/invoice-chase-send-error.json` (pair as Error Workflow on the main chase).

3. **Connect credentials** (buyer checklist)  
   - Create Google Sheets OAuth2 credential; select your chase spreadsheet + sheet/tab.  
   - **Create Gmail OAuth2 credential with `gmail.send` ONLY** — do **not** tick readonly/modify/full mailbox for the *main chase* sender. Exact scope: `https://www.googleapis.com/auth/gmail.send`.  
   - Map both to the placeholder credential names in the nodes (or re-select in each node).  
   - STOP-reply workflow (optional separate Gmail credential): needs read/poll scope — keep it **separate** from the send-only chase credential when possible.  
   - Optional webhook: set n8n env `CHASE_UNSUBSCRIBE_SECRET` (never commit it).

4. **Set spreadsheet ID / sheet name**  
   Update the Google Sheets nodes with your Spreadsheet ID and sheet/tab name (e.g. `Invoices`).

5. **Dry-run**  
   Use a test row with your own email; set `DueDate` so stage `0` is due; run once manually; confirm claim columns update and only one message arrives.

6. **Activate schedule**  
   Enable the workflow. Prefer hourly over every-minute.

7. **Production hygiene**  
   Pack defaults: `saveDataSuccessExecution` and `saveDataErrorExecution` are **`none`** (no long retention of PII in execution logs). Keep it that way in production; if you temporarily enable error saves for debugging, prune aggressively.

### Loom / setup notes (placeholders)

| Clip | URL |
|------|-----|
| Import workflow + credentials | `https://www.loom.com/share/PLACEHOLDER_IMPORT` |
| Sheet template + column walkthrough | `https://www.loom.com/share/PLACEHOLDER_SHEET` |
| First live send + claim columns | `https://www.loom.com/share/PLACEHOLDER_FIRST_SEND` |

**Checklist (show in Loom):** buyer creates the **main chase** Gmail credential with **`gmail.send` only** — no mailbox read/modify scopes on that credential.

---

## Deploy / import notes (n8n Cloud or self-host)

**n8n Cloud**

- Import JSON → attach Cloud OAuth credentials → set Spreadsheet ID → activate.
- Confirm Cloud plan rate limits vs your invoice volume.

**Self-host**

- Same import path; ensure Google OAuth redirect URIs match your n8n base URL.
- Keep n8n and its database off the public internet except the UI you protect. Main chase is schedule-only; the optional unsubscribe webhook needs a reachable HTTPS URL plus `CHASE_UNSUBSCRIBE_SECRET`.
- Back up workflows **without** credentials (n8n export with credentials stripped, plus `scripts/scrub-credentials.sh` on any git mirror).

---

## Security notes

1. **Never commit OAuth tokens** — use n8n credential store only; run `scripts/scrub-credentials.sh` on every commit.
2. **Least-privilege Gmail** — `gmail.send` only; no mailbox read/modify. Exact scope: `https://www.googleapis.com/auth/gmail.send`.
3. **Sheet = authz boundary** — share only with owner + n8n identity; edit access can change recipients and statuses and weaponize outbound mail.
4. **Send as buyer's authenticated Gmail** — From is the OAuth account. Custom `FromName` is display-only. If you ever send via a custom domain / alias, align **SPF, DKIM, and DMARC** or risk spoofing / spam folders.
5. **Claim-before-send** — write stage + timestamp before Gmail to reduce double-sends on cron overlap.
6. **Don't log full bodies / PII** — avoid Set nodes that dump entire messages; pack sets `saveDataSuccessExecution` / `saveDataErrorExecution` to **`none`** (short/no retention).
7. **No buyer credentials in this pack** — buyers connect their own Google accounts in their n8n instance.
8. **CAN-SPAM / business email tips** — use a real business identity; include clear purpose (invoice reminder); honor Paid and **STOP → Paused** (reply-STOP workflow + optional signed webhook); include your business name and reply path; don't buy lists; this is B2B transactional chase, not marketing blasts or collections/legal action. Stage cap: 3 emails max per invoice.
9. **HTML escaping** — Sheet-driven fields are escaped in the Code node before interpolation into HTML email bodies.
10. **Future Stripe/Wave** — read-only API keys only; never store full PAN / card numbers in Sheets.
11. **Unsubscribe webhook** — require `X-Chase-Secret` matching `CHASE_UNSUBSCRIBE_SECRET`; reject unauthenticated calls; never commit the real secret.

12. **Header injection** — Build Email strips `\r`/`\n` from subject, FromName, ReplyTo, and sendTo; rejects non-single-email `ClientEmail` before Gmail.
13. **Concurrency** — main chase `concurrency: 1` to limit overlapping claim races.
14. **Send-error path** — Gmail failure routes to Revert Claim (clears the claim and appends a timestamped error note); the Error Workflow stub may set `Paused` for broader failures.

See `docs/THREAT_NOTES.md` for the short security review checklist.

---

## License / sale

Source scaffold is **MIT** (`LICENSE`). Paid pack on Gumroad: **[https://kaletana.gumroad.com/l/vnhyc](https://kaletana.gumroad.com/l/vnhyc)** ($149). This GitHub repo is the public scaffold / docs mirror. **Do not publish buyer OAuth secrets.** Listing archive: `docs/GUMROAD_LISTING_DRAFT.md`.

---

## Changelog

- **0.2.1** — Pin live Gumroad store URL in README.
- **0.2.0** — STOP as product control (footers + reply-STOP + signed unsubscribe + Notes `\bSTOP\b` skip); header-injection hardening; concurrency=1; send-error revert + Error Workflow stub; saveData*=none; CI scrub; MIT LICENSE; Gumroad draft AR-not-collections.
- **0.1.0** — Initial shippable scaffold: MVP stages 0 / 3 / 7, claim-before-send, workflow, sample CSV, Gumroad draft, threat notes, credential scrub hook.
