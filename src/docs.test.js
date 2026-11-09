// Documentation tests. They read README and docs as text, so they cannot prove
// the Quickstart works, but each assertion fails when its claim is removed or
// stops matching the files it names.
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { test } from "node:test";

const root = new URL("..", import.meta.url).pathname;
const read = (p) => readFileSync(join(root, p), "utf8");
const readme = read("README.md");
const section = (md, heading) => {
  const start = md.indexOf(`\n## ${heading}`);
  assert.notEqual(start, -1, `README has no "## ${heading}" section`);
  const rest = md.slice(start + 1);
  const next = rest.indexOf("\n## ", 1);
  return next === -1 ? rest : rest.slice(0, next);
};

test("every repository path named in README and docs exists", () => {
  const pattern = /(?:\.github|scripts|docs|src)\/[A-Za-z0-9_./-]*[A-Za-z0-9_]/g;
  for (const file of ["README.md", "docs/SETUP.md", "docs/SECRETS.md", "docs/ROLLBACK.md", "docs/MONITORING.md", "docs/HANDOVER.md", "docs/CASE-STUDIES.md"]) {
    // URLs are not repository paths: drop them before matching.
    const text = read(file).replace(/https?:\/\/\S+/g, "");
    for (const path of text.match(pattern) ?? []) {
      assert.ok(existsSync(join(root, path)), `${file} names ${path}, which does not exist`);
    }
  }
});

test("every relative markdown link resolves", () => {
  for (const file of ["README.md", "docs/SETUP.md", "docs/SECRETS.md", "docs/ROLLBACK.md", "docs/MONITORING.md", "docs/HANDOVER.md", "docs/CASE-STUDIES.md"]) {
    for (const [, target] of read(file).matchAll(/\]\(([^)#\s]+)(?:#[^)]*)?\)/g)) {
      if (/^[a-z]+:/.test(target)) continue;
      assert.ok(existsSync(join(root, dirname(file), target)), `${file} links to ${target}, which does not exist`);
    }
  }
});

test("the Quickstart tells a new user the review gate fails closed", () => {
  const quickstart = section(readme, "Quickstart (30 minutes)");
  assert.match(quickstart, /Codex reviews the PR/, "Quickstart never names the review check");
  assert.match(quickstart, /CODEX_AUTH_JSON/, "Quickstart never names the secret that turns the check green");
  assert.match(quickstart, /fails? closed|red/i, "Quickstart does not say the first pull request is red until the secret is set");
});

test("the deploy row says the template ships a placeholder, not a live deploy", () => {
  const row = readme.split("\n").find((l) => l.includes(".github/workflows/deploy.yml"));
  assert.ok(row, "README has no row for deploy.yml");
  assert.match(row, /placeholder|you wire|uncomment/i, "deploy row implies a working deploy step");
  assert.match(read(".github/workflows/deploy.yml"), /placeholder/i, "deploy.yml no longer has a placeholder step, so the README row needs a fresh look");
});

test("the README opens with the standard header", () => {
  const top = readme.split("\n").slice(0, 12).join("\n");
  assert.match(top, /(?:!\[[^\]]*\]\(|<img[^>]*src=")https:\/\/raw\.githubusercontent\.com\/Synaptix-Innovations\/\.github\/main\/profile\/banner\.svg/, "no organisation banner");
  assert.match(top, /actions\/workflows\/ci\.yml\/badge\.svg/, "no native Actions status badge");
  assert.match(top, /\]\(https:\/\/github\.com\/Synaptix-Innovations\)/, "no link to the organisation page");
});
