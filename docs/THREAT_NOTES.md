# Threat notes — Escalating Invoice Chase

Short notes for Security review. Pack never ships buyer credentials.

## OAuth scopes

| Integration | Allowed | Forbidden |
|-------------|---------|-----------|
| Gmail | `https://www.googleapis.com/auth/gmail.send` **only** | `gmail.readonly`, `gmail.modify`, `mail.google.com`, full mailbox |
| Google Sheets | OAuth/service account limited to the chase spreadsheet | Broad Drive “see all files” if avoidable |

Buyers connect credentials inside **their** n8n instance. Repo exports use placeholder credential **names** only (`Google Sheets account`, `Gmail account`).

## Secrets handling

- Never commit `access_token`, `refresh_token`, `client_secret`, or `private_key`.
- Gate: `scripts/scrub-credentials.sh` (+ `.githooks/pre-commit`).
- n8n credential store / env only; strip credentials on any workflow re-export before git.

## Email spoofing (From vs authenticated Gmail)

- Messages send as the **buyer's authenticated Gmail** OAuth identity.
- `FromName` / `ReplyTo` from the Sheet are display / reply headers — they do **not** replace the authenticated mailbox.
- Custom domain / send-as aliases require correct **SPF, DKIM, and DMARC** on that domain; misalignment looks like spoofing and hurts deliverability.

## Sheet as authorization boundary

- Share the chase Sheet **only** with the owner and the n8n Google identity.
- Editor access can change `ClientEmail`, `Status`, amounts, and names → weaponized mail or silenced chase.
- Prefer a dedicated Sheet (not a general ops workbook).

## STOP / unsubscribe / Paid (mandatory product control)

- Clear purpose: invoice payment reminder (transactional B2B chase) — **not** collections or legal action.
- Stage cap: **3** (`0`, `3`, `7`).
- Honor `Status = Paid` and `Paused` immediately (no further sends). Main workflow **Compute Stage** skips both.
- **STOP path (required):** client replies with word **STOP** → `workflows/invoice-chase-stop-reply.json` sets `Status = Paused` and appends `[timestamp] STOP received` to `Notes`. That cancels remaining stages because the chase skips Paused.
- **Defense-in-depth:** Compute Stage also skips when `Notes` matches `\bSTOP\b` (even if Status is still Open). Prefer normalizing to `Paused` via the STOP workflows.
- **Optional signed unsubscribe webhook:** `workflows/invoice-chase-unsubscribe-webhook.json` — `POST` with body `{ "invoiceId": "..." }` and header **`X-Chase-Secret`** must match n8n env `CHASE_UNSUBSCRIBE_SECRET`. Reject missing/wrong secret (401). Never commit the real secret.
- Email footers on stages 0/3/7 tell the client: reply STOP to pause reminders for this invoice.
- CAN-SPAM-oriented tips (business identity, reply path, no purchased lists) live in README.

## Double-send / cron overlap

- Risk: overlapping schedule executions both read the same `LastStageSent` (claim TOCTOU).
- Mitigation: **claim-before-send** — write `LastStageSent` + `LastSentAt` **before** Gmail send; plus ~55 minute cooldown on `LastSentAt`; workflow **`concurrency: 1`**.
- **Send failure:** Gmail `onError` → Revert Claim (clear `LastStageSent` / `LastSentAt` + append a timestamped error note to `Notes`). Error Workflow stub `invoice-chase-send-error.json` may set `Status=Paused` on broader failures.

## Execution logging / PII

- Do not use Set nodes that dump full HTML bodies into items retained in execution history.
- Pack defaults: `saveDataSuccessExecution` and `saveDataErrorExecution` = **`none`** (no long retention). If temporarily enabled for debug, prune aggressively.

## Rate limits

- Prefer hourly schedule; respect Gmail sending quotas (personal vs Workspace).
- Volume = open invoices × stages over time — keep under provider limits.

## Future surfaces

| Surface | Requirement |
|---------|-------------|
| HTTP / Webhook trigger (unsubscribe) | Shared-secret header **`X-Chase-Secret`** must match env; reject missing/invalid secret; never commit real secret |
| Stripe / Wave sync | **Read-only** API keys; never store PAN / full card numbers in Sheets |
| HTML bodies | Escape/sanitize all Sheet-driven fields (implemented in Code node) |


## Header injection (email)

- Before Gmail: strip `\r` / `\n` from subject, FromName / senderName, ReplyTo, and sendTo.
- Validate `ClientEmail` is a **single** email shape; refuse send otherwise.

## Security findings fold-in (30662dd follow-up)

| ID | Mitigation in pack |
|----|--------------------|
| M1 STOP | Reply-STOP + signed unsubscribe set `Paused`; Compute skips Paid/Paused **and** Notes `\bSTOP\b` |
| M2 Header injection | Strip CR/LF + single-email validation in Build Email |
| M3 Claim TOCTOU | `concurrency: 1` on main chase |
| M4 Send error | Gmail error → Revert Claim with timestamped Notes append; Error Workflow stub → Paused |
| M5 Error log retention | `saveDataErrorExecution: none` |

## Pack distribution

- Public GitHub = docs + scrubbed workflow scaffold.
- Gumroad delivers the same pack; **never** includes buyer OAuth tokens.
