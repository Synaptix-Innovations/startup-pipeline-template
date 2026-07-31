# Setup — 30 minutes to a working pipeline

## 1. Create your repo (2 min)

Click **Use this template** → create your repo. Clone it.

```bash
npm test   # zero dependencies; should pass immediately on Node 20+
```

## 2. Swap in your app (10 min)

- Replace `src/` with your application.
- Keep (or add) a `/health` endpoint returning HTTP 200 when the app is genuinely
  able to serve traffic (DB reachable, config loaded) — not just "process exists".
- Update `package.json` scripts: `lint`, `test`, `start`. CI calls these names —
  the workflow itself doesn't need edits when the stack changes.

## 3. CI is already on (0 min)

Push to a branch, open a PR — `.github/workflows/ci.yml` runs lint → tests → a real
smoke that boots the app and curls `/health`. Make the branch protection rule:
`main` requires the `lint + test + smoke` check.

## 3b. Turn on the review gate (5 min)

The extra workflows only mean something once GitHub is told to enforce them.

**Branch protection** — Settings → Branches → add a rule for `main`:

- Require a pull request before merging
- Require status checks: `lint + test + smoke`
- Require review from Code Owners (pairs with `.github/CODEOWNERS` — edit the
  handle in that file first)

**Auto-merge** — Settings → General → *Allow auto-merge*. This is what lets
`auto-merge.yml` hand a pull request to GitHub instead of merging it itself.

**AI review (optional)** — add an `ANTHROPIC_API_KEY` secret. Without it the
review job skips quietly; nothing goes red.

> ⚠️ **Private repository on the free plan?** Branch protection is not
> available, and GitHub's auto-merge only turns on when a pull request is
> blocked by a required check — so with no protection rule there is nothing to
> wait for and the button never appears. On the free plan you get the CI gate,
> the path guard and the AI review as advisory signals, and you merge by hand.
> That is a perfectly good setup; just do not expect the automation to arm
> itself. Public repositories get branch protection for free.

## 4. Choose your deploy target (10 min)

**Cloudflare Pages / Workers (static & most frameworks, $0):** uncomment Option A
in `deploy.yml`, add `CLOUDFLARE_API_TOKEN` + `CLOUDFLARE_ACCOUNT_ID` secrets.

**VPS ($4–6/mo, any stack):** put `scripts/deploy.sh` on the server (adjust the
four variables at the top), create the systemd unit, uncomment Option B in
`deploy.yml`, add `DEPLOY_SSH_KEY` secret + `DEPLOY_USER`/`DEPLOY_HOST` variables.

Either way: create a **production environment** in repo Settings → Environments and
add yourself as required reviewer. Now every deploy needs a human click — that's
your deploy gate.

## 5. Monitoring (8 min)

Follow [`MONITORING.md`](MONITORING.md): a cron job + Telegram bot = you learn about
downtime from a ping, not from a customer tweet.

## 6. Before you forget (tonight, not "later")

- Read [`SECRETS.md`](SECRETS.md) and check nothing sensitive is in the repo.
- Read [`ROLLBACK.md`](ROLLBACK.md) once now — it's useless discovered during an outage.
- Run `scripts/rollback-drill.sh` on the server once you have deployed twice. A
  rollback path that has never been executed is a hope, not a control.
- Start filling [`HANDOVER.md`](HANDOVER.md) as you configure things. Future-you is
  the first person you'll hand this over to.
