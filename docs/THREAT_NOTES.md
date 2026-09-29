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

## STOP / unsubscribe / Paid

- Clear purpose: invoice payment reminder (transactional B2B chase).
- Stage cap: **3** (`0`, `3`, `7`).
- Honor `Status = Paid` and `Paused` immediately (no further sends).
- Suggest documenting client opt-out → set `Paused` or note `STOP` in `Notes` and pause manually.
- CAN-SPAM-oriented tips (business identity, reply path, no purchased lists) live in README.

## Double-send / cron overlap

- Risk: overlapping schedule executions both read the same `LastStageSent`.
- Mitigation: **claim-before-send** — write `LastStageSent` + `LastSentAt` **before** Gmail send; plus ~55 minute cooldown on `LastSentAt`.
- Residual: failed send after claim may skip that stage until operator resets claim columns carefully.

## Execution logging / PII

- Do not use Set nodes that dump full HTML bodies into items retained in execution history.
- Production: disable “save successful executions” (or aggressive pruning) so client emails / amounts are not retained longer than needed.

## Rate limits

- Prefer hourly schedule; respect Gmail sending quotas (personal vs Workspace).
- Volume = open invoices × stages over time — keep under provider limits.

## Future surfaces

| Surface | Requirement |
|---------|-------------|
| HTTP / Webhook trigger | Shared-secret header auth; reject missing/invalid secret |
| Stripe / Wave sync | **Read-only** API keys; never store PAN / full card numbers in Sheets |
| HTML bodies | Escape/sanitize all Sheet-driven fields (implemented in Code node) |

## Pack distribution

- Public GitHub = docs + scrubbed workflow scaffold.
- Gumroad delivers the same pack; **never** includes buyer OAuth tokens.
