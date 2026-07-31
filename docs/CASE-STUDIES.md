# Three failures this pipeline caught

Every control in this template exists because something broke. These are the
three that shaped it — real incidents on a real production box, not
hypotheticals from a blog post.

Read them as the argument for why the extra steps are worth their minute of CI
time. Each one passed the checks that a normal starter template ships with.

---

## 1. The service that restarted 21,000 times and looked fine

**Symptom.** A background service appeared healthy in every dashboard. The
process was up whenever anyone checked, memory looked normal, no alerts fired.
It had also restarted more than 21,000 times.

**What was actually happening.** The unit crashed seconds after boot because a
binary it needed was not on its PATH. A supervisor script noticed the service
was down and started it again — every two minutes, for weeks. Two mechanisms
each doing their job produced an infinite loop that neither reported: the
supervisor believed it was healing the service, and every manual check happened
to land in the window between a restart and the next crash.

**What a naive pipeline misses.** "Is the process running?" is the wrong
question, and it is the question most monitoring asks. The answer was yes,
thousands of times a day.

**What catches it here.** Restart counts are part of the health signal, not
just liveness — `docs/MONITORING.md` asks for the restart count and alerts on
*churn*, not only on *down*. A service that restarts more than a handful of
times an hour is broken even while it is technically up.

**The general lesson.** Any automatic remediation must count how often it
fires. Self-healing that never reports becomes an outage that never surfaces.

---

## 2. The deploy that passed its health check and served a blank page

**Symptom.** A deploy completed. `/health` returned 200. The site rendered
nothing — every visitor got a blank white page.

**What was actually happening.** The build produced an HTML page referencing
JavaScript bundles that were not in the output directory. The server started
fine and answered `/health` from application code that never touches the
frontend build. Every asset request 404'd. The process was healthy; the product
was dead.

**What a naive pipeline misses.** A health endpoint proves a process is
running. It says nothing about whether the thing the user loads actually works.
The gap between "the server responds" and "the page renders" is exactly where
this class of failure lives.

**What catches it here.** `scripts/smoke.sh` fetches the page a human would
land on, extracts every `.js` and `.css` it references, and requires all of
them to return 200. It runs in CI on every pull request and again after each
deploy, so the rollback fires automatically instead of waiting for a user to
complain.

**The general lesson.** Smoke-test what the user loads, not what the server
admits to. If your health check cannot fail when the frontend is broken, it is
not checking the product.

---

## 3. The dependency that vanished from the registry

**Symptom.** CI went red on a pull request that changed two lines of
documentation. `npm install` failed: a package the app depends on returned 404
for every version.

**What was actually happening.** The maintainer had unpublished it. Production
kept running only because the server still had the old copy in
`node_modules` — nothing had reinstalled since. Any clean install, any fresh
deploy, any new contributor's laptop would have hit the same wall. The failure
had already happened days earlier; nobody had triggered it yet.

**What a naive pipeline misses.** Deploys that reuse the existing
`node_modules` never notice a dependency has disappeared. The pipeline reports
green until the first clean build — usually during an incident, when you are
already rebuilding from scratch.

**What catches it here.** CI installs from a lockfile with the exact-versions
flag (`npm ci`, not `npm install`) on a clean runner, every run. A dependency
that cannot be fetched fails the build immediately, while it is an annoyance
rather than an emergency. The fix was to vendor the package into the repository
so the supply chain could not remove it again.

**The general lesson.** Your build must be reproducible from an empty
directory, and CI is the only place that gets proven regularly. If your deploy
is faster than a clean install, it is skipping the step that finds this.

---

## What these have in common

None of the three was found by the thing that was supposed to find it. The
monitoring reported healthy, the health check returned 200, and the deploy
succeeded. Each was caught by a check that asked a slightly harder question:

- not *is it running*, but *how often does it restart*
- not *does the server answer*, but *does the page load*
- not *does it build here*, but *does it build from nothing*

That is the whole idea behind this template. The pipeline is boring on purpose;
its value is that the boring checks ask the harder question.
