# Handover document — fill this in as you build

The test of good infrastructure isn't whether it runs — it's whether the next
person can operate it from the docs alone. Fill every section; "ask Alex" is not
documentation. Future-you counts as the next person.

## System overview

- **What the product does:** _one paragraph_
- **Architecture:** _app → where it runs → what it talks to (DB, queues, APIs)_
- **Repos:** _links + one line each_

## Environments

| Env | URL | Hosted on | Deployed by |
|---|---|---|---|
| production | | | `deploy.yml` (manual gate) |
| staging/preview | | | |

## Secrets map

| Secret | Used by | Stored in | How to rotate |
|---|---|---|---|
| | | | |

## Operations

- **Deploy:** _exact steps / which button_
- **Rollback:** _see ROLLBACK.md; anything project-specific here_
- **Logs:** _where and how (`journalctl -u ...`, dashboard link)_
- **Monitoring:** _what alerts exist, where they arrive, what to do for each_

## Scheduled jobs

| Job | Schedule | Where | What breaks if it stops |
|---|---|---|---|
| | | | |

## Known seams & scale-up path

_What will break first under load, and the pre-planned next step for each
(e.g. "SQLite → managed Postgres when writes exceed X/day")._

## Access

| System | Who has access | How to grant/revoke |
|---|---|---|
| | | |
