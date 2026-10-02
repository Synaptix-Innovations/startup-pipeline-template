// Structure tests for the review gate. They read the workflow as text, so they
// cannot prove it runs, but each assertion fails when its guard is deleted.
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const root = new URL("..", import.meta.url).pathname;
const read = (p) => readFileSync(join(root, p), "utf8");
const gate = read(".github/workflows/codex-review.yml");
// Comments are documentation; assertions must look at what actually runs.
const code = gate.split("\n").filter((l) => !/^\s*#/.test(l)).join("\n");

// The old gate's name is built from parts so this file does not match itself.
const OLD = ["ai", "review"].join("-");

test("the old review gate is gone and nothing refers to it", () => {
  assert.equal(existsSync(join(root, `.github/workflows/${OLD}.yml`)), false);
  const files = execFileSync("git", ["ls-files"], { cwd: root, encoding: "utf8" })
    .split("\n")
    .filter((f) => f && !f.endsWith("workflows.test.js") && /\.(md|ya?ml|js|sh|json)$/.test(f));
  const dead = [OLD, ["ANTHROPIC", "API_KEY"].join("_"), ["ai", "approved"].join("-")];
  for (const f of files) {
    for (const needle of dead) assert.ok(!read(f).includes(needle), `${f} still mentions ${needle}`);
  }
});

test("the model is pinned", () => {
  assert.match(code, /codex exec [^\n]*-m [a-z0-9][a-z0-9.-]+/);
});

test("job has a timeout and per-PR concurrency", () => {
  assert.match(code, /timeout-minutes: \d+/);
  assert.match(code, /concurrency:\n\s+group: codex-review-\$\{\{ github\.event\.pull_request\.number \}\}\n\s+cancel-in-progress: true/);
});

test("fork and Dependabot pull requests are skipped", () => {
  assert.match(code, /head\.repo\.full_name == github\.repository/);
  assert.match(code, /github\.actor != 'dependabot\[bot\]'/);
});

test("a missing CODEX_AUTH_JSON fails closed with a clear message", () => {
  const i = code.indexOf("if: env.CODEX_AUTH_JSON == ''");
  assert.ok(i > 0, "no step runs when the secret is empty");
  const step = code.slice(i, code.indexOf("- name:", i));
  assert.match(step, /\nexit 1|\s exit 1/);
  assert.match(step, /CODEX_AUTH_JSON/);
  assert.match(step, /::error::/);
  // Every later step must be skipped without the secret, or it would run blind.
  const rest = code.slice(code.indexOf("- name: Checkout"));
  for (const block of rest.split(/\n {6}- name: /).slice(1)) {
    assert.match(block, /if: (always\(\) && )?env\.CODEX_AUTH_JSON != ''/, block.split("\n")[0]);
  }
});

test("the failure-reason helper comes from the base branch", () => {
  assert.match(code, /git show "origin\/\$BASE_REF:scripts\/lib\/review-failure-reason\.sh"/);
  assert.match(code, /REVIEW_REASON_BIN: \$\{\{ runner\.temp \}\}\/review-failure-reason\.sh/);
  assert.ok(!/bash scripts\/lib\/review-failure-reason\.sh/.test(code), "helper must not run from the PR checkout");
});

test("the verdict is the last non-empty line and a non-APPROVE verdict is a red check", () => {
  assert.match(code, /has_verdict\(\) \{\n\s+grep -v '\^\[\[:space:\]\]\*\$' review\.txt[^\n]*\| tail -n 1/);
  assert.match(code, /VERDICT="\$\(grep -v '\^\[\[:space:\]\]\*\$' review\.txt \| tail -n 1/);
  assert.match(code, /\^VERDICT:\[\[:space:\]\]\*\(APPROVE\|REQUEST_CHANGES\)/);
  assert.match(code, /if \[ "\$VERDICT" = "APPROVE" \]/);
  const post = code.slice(code.indexOf("Post review + set label"));
  assert.match(post.slice(post.indexOf("else", post.indexOf('"$VERDICT" = "APPROVE"'))), /exit 1/);
});

test("the review post token is only visible to the post step and the model gets no tools", () => {
  const uses = code.split("\n").filter((l) => l.includes("secrets.REVIEW_POST_TOKEN"));
  assert.equal(uses.length, 1);
  const post = code.slice(code.indexOf("Post review + set label"));
  assert.ok(post.includes("secrets.REVIEW_POST_TOKEN"));
  assert.match(code, /--allowedTools ""/);
});

test("every action is pinned to a full commit SHA", () => {
  for (const wf of ["codex-review", "ci", "path-guard", "auto-merge"]) {
    for (const m of read(`.github/workflows/${wf}.yml`).matchAll(/^\s*- uses: (\S+)/gm)) {
      assert.match(m[1], /@[0-9a-f]{40}$/, `${wf}: ${m[1]}`);
    }
  }
});

test("auto-merge reads the codex-approved label, which the gate sets", () => {
  assert.match(read(".github/workflows/auto-merge.yml"), /has codex-approved/);
  assert.match(code, /--add-label codex-approved/);
});

test("the secrets are documented and never set by the repository", () => {
  const docs = read("docs/SETUP.md") + read("docs/SECRETS.md");
  for (const s of ["CODEX_AUTH_JSON", "CLAUDE_CODE_OAUTH_TOKEN", "REVIEW_POST_TOKEN"]) {
    assert.ok(docs.includes(s), `${s} is not documented`);
  }
  assert.match(read("README.md"), /codex-review\.yml/);
});

// --- the helper itself ---------------------------------------------------

const helper = join(root, "scripts/lib/review-failure-reason.sh");
function reason(stderr, stdout = "") {
  const d = mkdtempSync(join(tmpdir(), "reason-"));
  writeFileSync(join(d, "err"), stderr);
  writeFileSync(join(d, "out"), stdout);
  return execFileSync("bash", [helper, join(d, "err"), join(d, "out")], { encoding: "utf8" }).trim();
}

test("helper classifies the CLI's own error lines", () => {
  assert.equal(reason("ERROR: You've hit your usage limit"), "usage-limit");
  assert.equal(reason("ERROR: 401 Unauthorized"), "auth");
  assert.equal(reason("", "Failed to authenticate. API Error: 401 Invalid bearer token\n"), "auth");
  assert.equal(reason("", "API Error: 429 Too many requests\n"), "usage-limit");
});

test("helper does not let the echoed diff choose the diagnosis", () => {
  assert.equal(reason("+ token expired, refresh it\nsome progress line"), "unknown");
  assert.equal(reason("", "Review: the token handling looks expired\nVERDICT: APPROVE\n"), "unknown");
});
