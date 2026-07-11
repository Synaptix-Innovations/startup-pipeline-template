# Rollback — the 2-minute playbook

Read this **before** you need it. During an incident you will not want to think.

## If you deploy to a VPS with `scripts/deploy.sh`

The script keeps the last 3 releases and rolls back **automatically** when the
post-deploy health check fails. Manual rollback:

```bash
ls -1dt /opt/app/releases/*          # newest first; current is the symlink target
ln -sfn /opt/app/releases/<previous> /opt/app/current
sudo systemctl restart myapp
curl -fsS http://127.0.0.1:3000/health
```

## If you deploy to Cloudflare Pages / Vercel

Both keep every previous deployment. Dashboard → Deployments → previous one →
**Rollback / Promote**. ~30 seconds, no CLI needed. That's the main reason this
template recommends them for MVPs.

## If the bad change is in `main`

```bash
git revert <bad-sha>     # NOT reset — history stays intact, CI re-runs honestly
git push
```
Then deploy the revert through the normal gate. Never hotfix production by hand —
the next deploy will silently erase your hotfix.

## After any rollback

1. Write down (one paragraph): what broke, how you noticed, how long it took.
2. If the health check didn't catch it — extend the health check, not the process.
3. If you were afraid to roll back — that fear is the bug; fix the pipeline until
   rollback is boring.
