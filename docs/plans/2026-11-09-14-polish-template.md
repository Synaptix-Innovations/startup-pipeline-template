# Plan: polish the template (#14)

## Goal

A visitor who follows the README Quickstart on a fresh repository is not surprised, and every documentation claim matches the code on `main`.

## Scope

README.md, docs/*.md, comments in .github/workflows/ci.yml. No behaviour change in scripts or workflows.

## Non-goals

Deploying anywhere, paid services, secrets or credentials, workflow logic, publishing posts.

## Current evidence

| Fact | Exact evidence |
|---|---|
| Issue | Synaptix-Innovations/startup-pipeline-template#14, Project #1, In progress |
| Repository base | origin/main @ c5daee006ac6918438af4ff539539ce90ad5ed4f |
| Repository profile | Synaptix-Innovations/startup-pipeline-template, checked_at 2026-10-05T07:40:00Z, capability ready |
| Baseline | `npm run lint` exit 0; `npm test` 28 pass, 0 fail |
| Audit | every file path named in README and docs exists; every relative doc link resolves |
| Capability gaps | none |

## Audit findings

1. README Quickstart (steps 1-7) never mentions the review gate. It fails closed, so the first pull request in a fresh repository gets a red "Codex reviews the PR" check until a secret is set. This is documented only in docs/SETUP.md section 3b.
2. README says the gated deploy runs "deploy step → post-deploy health check". In deploy.yml both are commented placeholders and the live step is an echo. The README should say so.
3. ci.yml carries two near-duplicate comment blocks above the smoke step.
4. Issue #9: the standard README header is still open.

## File map

| File | Action | Responsibility |
|---|---|---|
| src/docs.test.js | create | tests that fail on the documentation defects below |
| README.md | modify | Quickstart review-gate step; deploy row wording; standard header (#9) |
| .github/workflows/ci.yml | modify | remove the duplicated comment only |
| package.json | modify | add src/docs.test.js to the lint syntax check |

## Acceptance-to-evidence map

| Criterion | Artifact | RED evidence | GREEN evidence | Level |
|---|---|---|---|---|
| Quickstart mentions the fail-closed review gate | README.md | docs.test.js fails: Quickstart has no review-gate step | passes | L1 |
| Deploy row states the placeholder honestly | README.md | docs.test.js fails | passes | L1 |
| Every path and link in README/docs resolves | README.md, docs | test passes now, guards regressions | passes | L1 |
| Standard header landed (#9) | README.md | header test fails | passes | L1 |
| No workflow behaviour change | ci.yml | git diff shows comments only | same | L0 |

## Risk, authority, approval

| Risk class | Protected target | Authority | Approval | Stop condition |
|---|---|---|---|---|
| Workflow path | .github/workflows/ci.yml (comment-only edit) | owner request on #14 | per path-guard, protected label expected | any non-comment diff in ci.yml |

## Validation

| Level | Applicable | Command |
|---|---|---|
| L0 | yes | `git diff --check`; `bash scripts/secret-scan.sh` |
| L1 | yes | `node --test src/docs.test.js` RED then GREEN |
| L2 | yes | `npm run lint`; `npm test` |
| L3-L5 | no | docs-only change |

## Rollback

- Trigger: a wrong claim or a red check after merge.
- Action: revert the merge commit.
- Verification: `npm test` on main.
- Deployment state: not-required.

## Definition of done

Acceptance rows satisfied, L0-L2 recorded, Codex review check green on the exact PR head, `review-code` recorded before merge, `done-code` with `not-required`.
