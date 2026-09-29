#!/usr/bin/env bash
# Fails if credential-like secrets appear in tracked/staged content.
# Matches assignment / JSON-key forms, not bare prose mentions in docs.
# Usage: ./scripts/scrub-credentials.sh [paths...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# JSON/"key": value, env KEY=, yaml key: value — not prose backticks alone
# Broadened: oauth tokens, API keys, BEGIN PRIVATE KEY blocks, service account fields
PATTERN='("access_token"|access_token|"refresh_token"|refresh_token|"client_secret"|client_secret|"private_key"|private_key|"api_key"|api_key|"apikey"|apikey|"auth_token"|auth_token|"id_token"|id_token|"client_id"[[:space:]]*[:=][[:space:]]*"[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com")[[:space:]]*[:=]'
PATTERN2='-----BEGIN ([A-Z0-9 ]+)?PRIVATE KEY-----'
PATTERN3='("type"[[:space:]]*:[[:space:]]*"service_account"|service_account\.json)'

if [[ $# -gt 0 ]]; then
  FILES=("$@")
else
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
    if [[ ${#FILES[@]} -eq 0 ]]; then
      mapfile -t FILES < <(git ls-files 2>/dev/null || true)
    fi
  else
    mapfile -t FILES < <(find . -type f \( -name '*.json' -o -name '*.md' -o -name '*.csv' -o -name '*.js' -o -name '*.ts' -o -name '*.yml' -o -name '*.yaml' -o -name '.env' -o -name '.env.*' \) ! -path './.git/*' 2>/dev/null || true)
  fi
fi

FOUND=0
for f in "${FILES[@]:-}"; do
  [[ -z "$f" || ! -f "$f" ]] && continue
  [[ "$f" == *"scrub-credentials.sh"* ]] && continue
  hit=0
  if grep -nE -i "$PATTERN" "$f" >/dev/null 2>&1; then
    hit=1
    echo "ERROR: possible credential material in: $f" >&2
    grep -nE -i "$PATTERN" "$f" >&2 || true
  fi
  if grep -nE "$PATTERN2" "$f" >/dev/null 2>&1; then
    hit=1
    echo "ERROR: private key block in: $f" >&2
    grep -nE "$PATTERN2" "$f" >&2 || true
  fi
  if grep -nE -i "$PATTERN3" "$f" >/dev/null 2>&1; then
    hit=1
    echo "ERROR: service account material in: $f" >&2
    grep -nE -i "$PATTERN3" "$f" >&2 || true
  fi
  # Long-looking JWT / Google token blobs assigned in JSON
  if grep -nE '("access_token"|"refresh_token"|"id_token")[[:space:]]*:[[:space:]]*"[A-Za-z0-9._-]{40,}"' "$f" >/dev/null 2>&1; then
    hit=1
    echo "ERROR: long token value in: $f" >&2
    grep -nE '("access_token"|"refresh_token"|"id_token")[[:space:]]*:[[:space:]]*"[A-Za-z0-9._-]{40,}"' "$f" >&2 || true
  fi
  if [[ "$hit" -eq 1 ]]; then
    FOUND=1
  fi
done

if [[ "$FOUND" -ne 0 ]]; then
  echo "" >&2
  echo "Commit blocked. Remove tokens/secrets (use n8n credential references only)." >&2
  echo "Allowed: placeholder credential names like \"Google Sheets account\" / \"Gmail account\"." >&2
  echo "Docs may mention the forbidden key names in prose; assignment/JSON forms (key: or key=) fail the check." >&2
  exit 1
fi

echo "scrub-credentials: OK (no access_token|refresh_token|client_secret|private_key|api_key assignment forms / key blocks)"
