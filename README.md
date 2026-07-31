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
| CI | `.github/workflows/ci.yml` | syntax check → tests → secret scan → real smoke (boots the app, validates every asset the page references) |
| Path guard | `.github/workflows/path-guard.yml` | deterministically labels a PR safe / protected by what it touches; unknown paths fail closed |
| AI review | `.github/workflows/ai-review.yml` | advisory second reviewer; treats the diff as untrusted input; skips quietly with no API key |
| Auto-merge | `.github/workflows/auto-merge.yml` | arms GitHub's auto-merge only on safe-path ∧ AI-approved ∧ green CI — no model ever merges |
| Secret scan | `scripts/secret-scan.sh` | fails the build on committed keys or `.env` files |
| Rollback drill | `scripts/rollback-drill.sh` | deploys a deliberately broken release and proves the rollback fires |
| Gated deploy | `.github/workflows/deploy.yml` | manual trigger → full CI → deploy step → post-deploy health check |
| Case studies | `docs/CASE-STUDIES.md` | three real production failures and the check that catches each |
| Deploy script | `scripts/deploy.sh` | VPS variant: sync → restart → health check → automatic rollback |
| Monitoring | `scripts/healthcheck.sh` + `docs/MONITORING.md` | cron + Telegram alert; $0 |
| Secrets | `docs/SECRETS.md` | where secrets live, where they never go, how to rotate |
| Rollback | `docs/ROLLBACK.md` | the 2-minute playbook, written before you need it |
| Handover | `docs/HANDOVER.md` | fill-in template documenting the whole setup for the next operator |

## What makes this different from a starter template

Most pipeline boilerplate stops at "lint, test, deploy". Everything below exists
because something actually broke — the incidents are written up in
[`docs/CASE-STUDIES.md`](docs/CASE-STUDIES.md):

- **The smoke test validates assets, not just `/health`.** A process can answer
  200 while serving a blank page because the build referenced bundles that were
  never emitted. `scripts/smoke.sh` fetches the page and requires every `.js`
  and `.css` it references to return 200.
- **Path classification is deterministic and fails closed.** A pull request is
  labelled by what it touches, by code you can read — and a path nobody
  anticipated is treated as protected, never as safe.
- **The AI reviewer is advisory and cannot merge.** It applies a label; GitHub
  merges, and only after the required checks pass. The diff is treated as
  untrusted input, because a pull request can contain text aimed at the model.
- **The rollback is drilled, not documented.** `scripts/rollback-drill.sh`
  deploys a release that cannot pass its health check and asserts that the
  previous one is restored and serving.
- **Secrets are scanned on every pull request**, because rotating a key is cheap
  before it reaches a remote and expensive afterwards.

None of this needs a paid plan, a cluster, or a vendor. It needs about an hour
of setup, once.

### Running where it was written

This is not a template we wrote and never used. Every active repository in the
organisation runs the same shape of gate — the differences are the checks each
one actually needs:

| Repository | Gate |
|---|---|
| synaptix-brain (app) | static + unit + secret scan + build, AI review, path guard, auto-merge |
| ibkr-bot (trading) | tests + AI review |
| chat-worker (edge) | install from lockfile + tests + secret scan |
| knowledge-base (wiki) | internal link check + secret scan |
| synaptix-infra (config as code) | shellcheck + secret scan + no inline credentials in systemd units |

The wiki checker found a dead link on its first run. The infra scanner flagged a
connection string on its first run, which turned out to be correct code — and
that false positive is why it now distinguishes an interpolated variable from a
literal password. A scanner that cries wolf gets disabled within a week.

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
