#!/usr/bin/env bash
# Prove the rollback works — before you need it at 2am.
#
#   scripts/rollback-drill.sh            # run on the server, monthly
#
# A rollback path that has never been executed is a hope, not a control. This
# drill deliberately deploys a release that cannot pass its health check and
# asserts three things:
#
#   1. deploy.sh refuses the bad release (exit code 1)
#   2. `current` still points at the release that was live before
#   3. the service is answering again when the drill finishes
#
# It is destructive-by-design in a controlled way: the app does go down for the
# seconds between the bad restart and the rollback. Run it in a maintenance
# window, not during a demo.
set -uo pipefail

APP_DIR="${APP_DIR:-/opt/app}"
SERVICE="${SERVICE:-myapp}"
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:3000/health}"
DEPLOY="${DEPLOY:-$APP_DIR/current/scripts/deploy.sh}"

RELEASES_DIR="$APP_DIR/releases"
CURRENT_LINK="$APP_DIR/current"

pass() { echo "PASS: $*"; }
fail() { echo "FAIL: $*"; exit 1; }

command -v curl > /dev/null || fail "curl is required"
[ -x "$DEPLOY" ] || fail "deploy script not found or not executable: $DEPLOY"

BEFORE="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
[ -n "$BEFORE" ] || fail "no current release to roll back to — deploy once first"
echo "==> Live release before drill: $BEFORE"

curl -fsS --max-time 10 "$HEALTH_URL" > /dev/null 2>&1 \
  || fail "service is already unhealthy — fix that before drilling"

# Build a release that starts but can never pass the health check.
STAMP="drill-$(date +%Y%m%d%H%M%S)"
BROKEN="$RELEASES_DIR/$STAMP"
echo "==> Staging deliberately broken release: $BROKEN"
mkdir -p "$BROKEN"
cp -r "$BEFORE/." "$BROKEN/" 2>/dev/null || fail "could not copy the live release"

# Break it in the way that matters: the health endpoint stops answering.
cat > "$BROKEN/DRILL_BROKEN" <<'EOF'
This release was created by scripts/rollback-drill.sh and is expected to fail
its health check. If you are reading this in a live release directory, the
drill did not clean up — investigate before trusting the rollback path.
EOF
if [ -f "$BROKEN/src/server.js" ]; then
  printf '\nprocess.exit(1);\n' >> "$BROKEN/src/server.js"
else
  echo "!! Could not find src/server.js in the release — adapt this drill to your app"
fi

echo "==> Running the deploy against the broken release (expecting a refusal)"
set +e
DRILL_RELEASE="$BROKEN" "$DEPLOY"
DEPLOY_RC=$?
set -e

AFTER="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"

echo
echo "==> Results"
[ "$DEPLOY_RC" -ne 0 ] \
  && pass "deploy refused the bad release (exit $DEPLOY_RC)" \
  || fail "deploy reported success on a release that cannot be healthy"

[ "$AFTER" = "$BEFORE" ] \
  && pass "current still points at the previous release" \
  || fail "current moved to $AFTER — rollback did not restore the previous release"

if curl -fsS --max-time 15 "$HEALTH_URL" > /dev/null 2>&1; then
  pass "service is healthy after the drill"
else
  fail "service is NOT healthy after the drill — this is the outage the drill exists to prevent"
fi

echo "==> Cleaning up $BROKEN"
rm -rf "$BROKEN"

echo
echo "ROLLBACK DRILL PASSED — record the date in docs/ROLLBACK.md"
