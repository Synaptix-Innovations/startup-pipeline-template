#!/usr/bin/env bash
# Health check that also fetches every asset the page references.
#
#   scripts/smoke.sh http://127.0.0.1:3000
#
# Why not just curl /health: a health endpoint answers 200 from a process that
# is running, which is not the same as an app that works. A build can ship a
# page referencing JavaScript bundles that are missing or corrupt — the process
# is healthy, /health is green, and every visitor gets a blank screen.
#
# We shipped exactly that failure once (see docs/CASE-STUDIES.md). This script
# is the fix: fetch the page, extract the assets it references, and require all
# of them to return 200 before calling the deploy good.
set -uo pipefail

BASE_URL="${1:-http://127.0.0.1:3000}"
HEALTH_PATH="${HEALTH_PATH:-/health}"
PAGE_PATH="${PAGE_PATH:-/}"
TIMEOUT="${SMOKE_TIMEOUT:-10}"

fail() { echo "SMOKE FAIL: $*"; exit 1; }

# 1. The process answers at all.
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "${BASE_URL}${HEALTH_PATH}" || echo 000)"
[ "$code" = "200" ] || fail "${HEALTH_PATH} returned ${code}"
echo "ok  ${HEALTH_PATH}"

# 2. The page a human would land on renders.
page="$(curl -s --max-time "$TIMEOUT" "${BASE_URL}${PAGE_PATH}")" || fail "${PAGE_PATH} did not respond"
code="$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "${BASE_URL}${PAGE_PATH}" || echo 000)"
[ "$code" = "200" ] || fail "${PAGE_PATH} returned ${code}"
echo "ok  ${PAGE_PATH}"

# 3. Every script/stylesheet the page references is actually served.
assets="$(printf '%s' "$page" \
  | grep -oE '(src|href)="[^"]+\.(js|css|mjs)(\?[^"]*)?"' \
  | sed -E 's/^(src|href)="//; s/"$//' \
  | sort -u)"

if [ -z "$assets" ]; then
  echo "ok  no js/css assets referenced (nothing to validate)"
  exit 0
fi

failed=0
while IFS= read -r asset; do
  [ -z "$asset" ] && continue
  case "$asset" in
    http://*|https://*) url="$asset" ;;   # absolute, possibly a CDN
    /*)  url="${BASE_URL}${asset}" ;;
    *)   url="${BASE_URL}/${asset}" ;;
  esac
  code="$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" "$url" || echo 000)"
  if [ "$code" = "200" ]; then
    echo "ok  asset ${asset}"
  else
    echo "BAD asset ${asset} -> ${code}"
    failed=1
  fi
done <<< "$assets"

[ "$failed" -eq 0 ] || fail "one or more referenced assets are not served"

echo "SMOKE PASS: ${BASE_URL}"
