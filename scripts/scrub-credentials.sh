#!/usr/bin/env bash
# Fails if credential-like secrets appear in tracked/staged content.
# Matches assignment / JSON-key forms, not bare prose mentions in docs.
# Usage: ./scripts/scrub-credentials.sh [paths...]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# JSON/"key": value, env KEY=, yaml key: value — not prose backticks alone
PATTERN='("access_token"|access_token|"refresh_token"|refresh_token|"client_secret"|client_secret|"private_key"|private_key)[[:space:]]*[:=]'

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
  if grep -nE -i "$PATTERN" "$f" >/dev/null 2>&1; then
    echo "ERROR: possible credential material in: $f" >&2
    grep -nE -i "$PATTERN" "$f" >&2 || true
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

echo "scrub-credentials: OK (no access_token|refresh_token|client_secret|private_key assignment forms)"
