#!/usr/bin/env bash
# Guarded VPS deploy: sync → restart → health check → automatic rollback.
# Run ON the server (via ssh from CI or by hand). Adjust the four variables.
set -euo pipefail

APP_DIR="/opt/app"
SERVICE="myapp"                          # systemd unit name
HEALTH_URL="http://127.0.0.1:3000/health"
KEEP_RELEASES=3

RELEASES_DIR="$APP_DIR/releases"
CURRENT_LINK="$APP_DIR/current"
STAMP="$(date +%Y%m%d%H%M%S)"
NEW_RELEASE="$RELEASES_DIR/$STAMP"

echo "==> Fetching latest main"
mkdir -p "$NEW_RELEASE"
git -C "$APP_DIR/repo" fetch origin main
git -C "$APP_DIR/repo" --work-tree="$NEW_RELEASE" checkout origin/main -- .

echo "==> Installing / building"
cd "$NEW_RELEASE"
# npm ci --omit=dev   # uncomment when you have dependencies
# npm run build       # uncomment when you have a build step

PREVIOUS="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"

echo "==> Switching current -> $STAMP"
ln -sfn "$NEW_RELEASE" "$CURRENT_LINK"
sudo systemctl restart "$SERVICE"

echo "==> Health check"
for i in $(seq 1 20); do
  if curl -fsS "$HEALTH_URL" > /dev/null 2>&1; then
    echo "==> Healthy. Deploy complete."
    # Prune old releases
    ls -1dt "$RELEASES_DIR"/* | tail -n +$((KEEP_RELEASES + 1)) | xargs -r rm -rf
    exit 0
  fi
  sleep 1
done

echo "!! Health check failed — rolling back"
if [ -n "$PREVIOUS" ] && [ -d "$PREVIOUS" ]; then
  ln -sfn "$PREVIOUS" "$CURRENT_LINK"
  sudo systemctl restart "$SERVICE"
  echo "!! Rolled back to $PREVIOUS"
fi
exit 1
