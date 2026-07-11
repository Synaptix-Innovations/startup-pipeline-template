#!/usr/bin/env bash
# $0 monitoring: cron-driven health check with a Telegram alert.
# Crontab: */5 * * * * /opt/app/scripts/healthcheck.sh
# Secrets come from the environment file — never hardcode them here.
set -euo pipefail

# shellcheck disable=SC1091
source /opt/app/.env   # provides HEALTH_URL, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID

STATE_FILE="/tmp/healthcheck.down"

if curl -fsS --max-time 10 "$HEALTH_URL" > /dev/null 2>&1; then
  # Recovered? Tell the human once.
  if [ -f "$STATE_FILE" ]; then
    rm -f "$STATE_FILE"
    curl -fsS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d chat_id="${TELEGRAM_CHAT_ID}" \
      -d text="✅ ${HEALTH_URL} is back up" > /dev/null
  fi
  exit 0
fi

# Down. Alert once per outage, not every 5 minutes.
if [ ! -f "$STATE_FILE" ]; then
  touch "$STATE_FILE"
  curl -fsS "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d chat_id="${TELEGRAM_CHAT_ID}" \
    -d text="🔴 ${HEALTH_URL} is DOWN" > /dev/null
fi
exit 1
