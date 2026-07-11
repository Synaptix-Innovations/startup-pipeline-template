# Startup Pipeline Template — $0 to revenue

[![CI](https://github.com/Synaptix-Innovations/startup-pipeline-template/actions/workflows/ci.yml/badge.svg)](https://github.com/Synaptix-Innovations/startup-pipeline-template/actions/workflows/ci.yml)

A production-grade delivery pipeline for startups that haven't made money yet.
CI, gated deploys, health checks, rollback, monitoring, and secrets discipline —
on free-tier infrastructure, with **zero runtime dependencies** in the template itself.

The placeholder app is ~40 lines of Node. It exists so every stage of the pipeline
runs for real and the badge above is earned, not decorative. **Swap in your stack;
the pipeline is the point.**

## Philosophy

Most startups die with either no pipeline (founder deploys by hand at 2am) or an
over-built one (Kubernetes for zero users, $400/month for an MVP). This template is
the middle path:

- **$0 until revenue.** Everything here runs on free tiers: GitHub Actions, Cloudflare
  Pages / a $5 VPS, UptimeRobot, Telegram alerts.
- **Boring and observable.** Every deploy is gated by CI, checked for health, and
  reversible. No magic.
- **Handover-ready.** The docs are written so the *next* person (a hire, a contractor,
  future-you) can operate everything without asking questions.

## What you get

| Stage | File | What it does |
|---|---|---|
| CI | `.github/workflows/ci.yml` | syntax check → tests → real smoke (boots the app, curls `/health`) |
| Gated deploy | `.github/workflows/deploy.yml` | manual trigger → full CI → deploy step → post-deploy health check |
| Deploy script | `scripts/deploy.sh` | VPS variant: sync → restart → health check → automatic rollback |
| Monitoring | `scripts/healthcheck.sh` + `docs/MONITORING.md` | cron + Telegram alert; $0 |
| Secrets | `docs/SECRETS.md` | where secrets live, where they never go, how to rotate |
| Rollback | `docs/ROLLBACK.md` | the 2-minute playbook, written before you need it |
| Handover | `docs/HANDOVER.md` | fill-in template documenting the whole setup for the next operator |

## Quickstart (30 minutes)

1. **Use this template** (button above) → your repo.
2. `npm test` locally — everything is zero-dependency Node 20+, so this just works.
3. Replace `src/` with your app; keep a `/health` endpoint that returns 200.
4. Update the `lint` / `test` / `start` scripts in `package.json` for your stack.
5. Pick a deploy target in `.github/workflows/deploy.yml` (Cloudflare Pages example
   included; VPS variant via `scripts/deploy.sh`).
6. Add the secrets listed in `docs/SECRETS.md` to your repo settings.
7. Follow `docs/MONITORING.md` (10 minutes) so you learn about downtime from a
   Telegram ping, not from a customer.

Full walkthrough: [`docs/SETUP.md`](docs/SETUP.md).

## Cost reality check

| Piece | This template | Typical over-build |
|---|---|---|
| CI/CD | GitHub Actions free tier | self-hosted Jenkins on a $40/mo box |
| Hosting | Cloudflare Pages / $5 VPS | managed k8s from day one, $150+ |
| Monitoring | UptimeRobot + Telegram, $0 | Datadog starter, $31+/host |
| **Monthly total** | **$0–5** | **$200+ before the first customer** |

Scale up when revenue makes the pipeline the bottleneck — the handover doc tells the
next operator exactly where the seams are.

## Who made this

[Synaptix Innovations](https://github.com/Synaptix-Innovations) — we build
startup-ready pipelines on free and low-cost infrastructure, then hand them over
with docs like these. This template is the free, self-serve version of what we do.

MIT licensed. Issues and PRs welcome.
