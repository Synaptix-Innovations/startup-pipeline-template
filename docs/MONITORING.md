# Monitoring for $0

Goal: **you find out about downtime before your users do**, without paying for an
observability platform your MVP doesn't need yet.

## Layer 1 — external uptime check (5 min, $0)

[UptimeRobot](https://uptimerobot.com) free tier: 50 monitors, 5-minute interval.
Point it at `https://your-app/health`, set the alert contact to email (or their
Telegram integration). This catches "the whole server is gone" — which your own
cron can't report, because it's on the same server.

## Layer 2 — server-side health cron + Telegram (10 min, $0)

External checks see the outside; this sees the inside (app up but degraded).

1. Create a bot: message [@BotFather](https://t.me/BotFather) → `/newbot` → copy the token.
2. Get your chat id: message the bot once, then
   `curl https://api.telegram.org/bot<TOKEN>/getUpdates` → `chat.id`.
3. Add to `/opt/app/.env`:
   ```
   HEALTH_URL=http://127.0.0.1:3000/health
   TELEGRAM_BOT_TOKEN=...
   TELEGRAM_CHAT_ID=...
   ```
4. Crontab: `*/5 * * * * /opt/app/scripts/healthcheck.sh`

The script alerts **once per outage** and once on recovery — not every 5 minutes.

## Layer 3 — when to graduate

Add real observability when any of these happen: paying customers, >1 service,
an incident you couldn't diagnose from logs. Until then, `journalctl -u myapp`
plus the two layers above cover an MVP honestly.

## Make `/health` mean something

A health endpoint that returns 200 while the DB is unreachable is worse than none.
Check your critical dependency (one cheap query / ping) and return 503 when it
fails — both workflows and both monitoring layers immediately become truthful.
