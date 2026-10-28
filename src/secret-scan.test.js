// Drives scripts/secret-scan.sh for real, in a scratch git repository, once per
// pattern. Reading the PATTERNS list and trusting it is what let the private-key
// pattern go undetected: it starts with "-", grep took it for an option, exited 2,
// and the script read that as "no match".
import assert from "node:assert/strict";
import { spawnSync, execFileSync } from "node:child_process";
import { chmodSync, copyFileSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";

const root = new URL("..", import.meta.url).pathname;

// Every sample is assembled from parts so this file does not trip the scan itself.
const samples = {
  "AWS access key id": ["AKIA", "3XZQ7PLMWVN2KDTR"].join(""),
  "AWS temporary key id": ["ASIA", "3XZQ7PLMWVN2KDTR"].join(""),
  "private key": ["-----BEGIN", "RSA PRIVATE KEY-----"].join(" "),
  "GitHub token": ["ghp_", "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8"].join(""),
  "Slack token": ["xoxb", "-1234567890-abcdefghij"].join(""),
  "OpenAI-style key": ["sk-", "xJ4kQ2vR8mZ7pL1nT6wY3bC5dF9gH0sA"].join(""),
  "Google API key": ["AIza", "SyA1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q"].join(""),
  "Telegram bot token": ["123456789:", "AA", "b".repeat(33)].join(""),
  "DB URL with an inline password": ["postgres", "://app:s3cret@db:5432/prod"].join(""),
};

function repoWith(files) {
  const dir = mkdtempSync(join(tmpdir(), "secret-scan-"));
  mkdirSync(join(dir, "scripts"));
  copyFileSync(join(root, "scripts/secret-scan.sh"), join(dir, "scripts/secret-scan.sh"));
  for (const [name, body] of Object.entries(files)) writeFileSync(join(dir, name), body);
  execFileSync("git", ["init", "-q"], { cwd: dir });
  execFileSync("git", ["add", "-A"], { cwd: dir });
  return dir;
}

function scan(dir) {
  return spawnSync("bash", ["scripts/secret-scan.sh"], { cwd: dir, encoding: "utf8" });
}

test("a clean repository passes", () => {
  const dir = repoWith({ "notes.md": "nothing to see here\n" });
  try {
    const r = scan(dir);
    assert.equal(r.status, 0, r.stdout + r.stderr);
    assert.match(r.stdout, /Secret scan passed\./);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

for (const [kind, value] of Object.entries(samples)) {
  test(`a tracked ${kind} fails the scan`, () => {
    const dir = repoWith({ "leak.txt": `config: ${value}\n` });
    try {
      const r = scan(dir);
      assert.equal(r.status, 1, `${kind} was not caught:\n${r.stdout}${r.stderr}`);
      assert.match(r.stdout, /possible credential in leak\.txt/);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}

// Root reads any file, so the unreadable case only means something as a user.
test("a file grep cannot read fails the scan instead of passing", { skip: process.getuid?.() === 0 }, () => {
  const dir = repoWith({ "locked.txt": "anything\n" });
  try {
    chmodSync(join(dir, "locked.txt"), 0o000);
    const r = scan(dir);
    assert.notEqual(r.status, 0, `an unreadable file passed:\n${r.stdout}${r.stderr}`);
    assert.doesNotMatch(r.stdout, /Secret scan passed\./);
  } finally {
    chmodSync(join(dir, "locked.txt"), 0o644);
    rmSync(dir, { recursive: true, force: true });
  }
});
