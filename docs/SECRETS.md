# Secrets discipline

The whole policy in one line: **secrets live in exactly two places — GitHub Actions
secrets (for CI/CD) and a chmod-600 `.env` file on the server (for runtime). Nowhere
else, ever.**

## Where secrets go

| Secret | Lives in | Never in |
|---|---|---|
| Deploy keys, API tokens for CI | Repo Settings → Secrets → Actions | workflow YAML, code |
| `CODEX_AUTH_JSON`, `CLAUDE_CODE_OAUTH_TOKEN`, `REVIEW_POST_TOKEN` (review gate) | Repo Settings → Secrets → Actions, set by the owner | the repo, PR comments, logs |
| Runtime config (DB URL, API keys) | `/opt/app/.env`, `chmod 600`, owned by the app user | the repo, Docker images, logs |
| Telegram alert bot token | server `.env` | cron files, scripts |

## Rules that prevent the classic incidents

1. **`.env` is in `.gitignore` from day one** (already done in this template). Check
   before every first push of a new repo: `git ls-files | grep -i env`.
2. **No secrets in cron lines or scripts.** Scripts `source /opt/app/.env` — see
   `scripts/healthcheck.sh` for the pattern.
3. **Echo nothing.** CI logs are visible to everyone with repo access; GitHub masks
   registered secrets, but only exact matches — don't build strings around them.
4. **Rotation is a 5-minute job if you keep the map.** List every secret and where
   it's used in `HANDOVER.md`; rotating = generate new → update the 1–2 places from
   the map → revoke old.
5. **If a secret ever touches git history, it is burned.** Rotate immediately;
   `git filter-repo` later. History rewriting is cleanup, not remediation.

## Adding a secret-scan gate ($0)

```bash
# .git/hooks/pre-commit (or a lefthook/husky hook)
git diff --cached | grep -E "(api[_-]?key|secret|token|password)\s*[:=]\s*['\"][A-Za-z0-9]{16,}" \
  && echo "Possible secret in diff — commit blocked" && exit 1 || exit 0
```

Crude, but it has caught real keys. Upgrade to `gitleaks` when you have 10 minutes.
