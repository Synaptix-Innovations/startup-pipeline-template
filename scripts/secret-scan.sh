#!/usr/bin/env bash
# Fail the build if a credential is about to be committed.
#
# Runs in CI (see .github/workflows/ci.yml) and, if you install it, as a
# pre-commit hook. Zero dependencies: grep and git only.
#
# This is a tripwire, not a vault scanner. It catches the accidents that
# actually happen — a pasted key, a committed .env, a token in a config —
# early enough that rotating the secret is the only cleanup needed. Once a
# secret reaches a public remote, rotation is mandatory and this script is
# too late.
set -uo pipefail

# Patterns worth failing a build over. Add your provider's key shape here.
PATTERNS=(
  'AKIA[0-9A-Z]{16}'                        # AWS access key id
  'ASIA[0-9A-Z]{16}'                        # AWS temporary key id
  '-----BEGIN [A-Z ]*PRIVATE KEY-----'      # any private key
  'gh[pousr]_[A-Za-z0-9]{36,}'              # GitHub tokens
  'xox[baprs]-[A-Za-z0-9-]{10,}'            # Slack tokens
  'sk-[A-Za-z0-9]{32,}'                     # OpenAI-style keys
  'AIza[0-9A-Za-z_-]{35}'                   # Google API key
  '[0-9]{9,10}:AA[A-Za-z0-9_-]{33}'         # Telegram bot token
  'postgres(ql)?://[^:]+:[^@]+@'            # DB URL with an inline password
)

# Files that are allowed to contain key-shaped strings: this script, and any
# documentation that shows what a leaked key looks like.
ALLOWLIST_REGEX='^(scripts/secret-scan\.sh|docs/SECRETS\.md)$'

if [ -d .git ]; then
  FILES="$(git ls-files)"
else
  FILES="$(find . -type f -not -path './.git/*' -not -path './node_modules/*' | sed 's|^\./||')"
fi

STATUS=0

# 1. Committed env files. The single most common leak, and the easiest to miss
#    because it works fine on the machine that committed it.
while IFS= read -r file; do
  case "$file" in
    .env|.env.*|*/.env|*/.env.*)
      case "$file" in
        *.example|*.sample|*.template) continue ;;
      esac
      echo "SECRET SCAN: environment file is tracked in git: $file"
      STATUS=1
      ;;
  esac
done <<< "$FILES"

# 2. Key-shaped strings anywhere in tracked content.
while IFS= read -r file; do
  [ -z "$file" ] && continue
  [ -f "$file" ] || continue
  echo "$file" | grep -qE "$ALLOWLIST_REGEX" && continue
  # Skip binaries — grep -I does this for us.
  for pattern in "${PATTERNS[@]}"; do
    # -e, because the private-key pattern starts with "-": without it grep reads
    # the pattern as an option and exits 2. Exit 1 is the only "no match"; any
    # other status means the file was not scanned, and that must not pass.
    grep_status=0
    hits="$(grep -InaE -e "$pattern" -- "$file" 2>&1)" || grep_status=$?
    case "$grep_status" in
      0)
        echo "SECRET SCAN: possible credential in $file"
        printf '%s\n' "$hits" | head -3 | sed 's/^/    /'
        STATUS=1
        ;;
      1) ;;
      *)
        echo "SECRET SCAN: could not scan $file (grep exit $grep_status): $hits"
        STATUS=1
        ;;
    esac
  done
done <<< "$FILES"

if [ "$STATUS" -eq 0 ]; then
  echo "Secret scan passed."
else
  echo
  echo "If one of these is a false positive, add the file to ALLOWLIST_REGEX."
  echo "If it is real: rotate the credential first, then remove it from history."
fi

exit "$STATUS"
