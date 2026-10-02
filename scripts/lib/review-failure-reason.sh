#!/usr/bin/env bash
# Why the review produced no verdict: `auth`, `usage-limit`, or `unknown`.
#
# The reviewer CLI echoes its prompt to stderr, and the prompt contains the pull
# request diff, so that log holds untrusted text. Classifying by grepping the
# whole file lets the diff decide what the gate says about itself (a diff that
# merely contains the word "expired" must not announce an expired credential).
# Only lines the CLI itself emits as errors are classified; every line of the
# diff is evidence of nothing.
#
# The workflow runs this from the BASE branch, never from the PR checkout: it
# executes with the review credentials in the job environment.
#
# Usage: review-failure-reason.sh <stderr-log> [stdout-log]
set -uo pipefail

log="${1:-}"
# The reviewer's STDOUT, optional. Needed because the Claude CLI reports an
# authentication failure there and leaves stderr empty:
#
#   $ CLAUDE_CODE_OAUTH_TOKEN=bad claude -p ...
#   stdout: Failed to authenticate. API Error: 401 Invalid bearer token
#   stderr: (nothing)
#
# Reading only stderr therefore classified an expired fallback credential as
# `unknown`, and the workflow printed "produced no verdict" instead of the
# branch naming `claude setup-token`. Codex writes `ERROR:` to stderr, which is
# why only the Claude fallback needs this stdout check.
out="${2:-}"
[ -n "$log" ] || { echo "usage: review-failure-reason.sh <stderr-log> [stdout-log]" >&2; exit 2; }

# A CLI error on stdout, distinguished from a review that merely lacks a verdict.
# Both conditions are load-bearing: the first non-empty line must BE the error,
# which a real review's opening line is not, and a patch line quoting one starts
# with `+`. Without the anchor this would reintroduce the problem one file over, with
# the diff choosing the diagnosis again.
# The CLI's own error line from stdout, if that is what stdout holds. Returns
# the line so it goes through the SAME classification as stderr's — an earlier
# version answered `auth` for anything with this prefix, which made
# `API Error: 429 Too many requests` recommend refreshing a healthy credential.
# One path, one set of patterns.
#
# Both conditions are load-bearing: the first non-empty line must BE the error,
# which a real review's opening line is not, and a patch line quoting one starts
# with `+`. Without the anchor this would reintroduce the problem one stream over, with
# the diff choosing the diagnosis again.
stdout_error_line() {
  [ -n "$out" ] && [ -s "$out" ] || return 1
  grep -qE 'VERDICT:[[:space:]]*(APPROVE|REQUEST_CHANGES)' "$out" && return 1
  local first
  first=$(grep -m1 -vE '^[[:space:]]*$' "$out")
  grep -qE '^[[:space:]]*(Failed to authenticate|API Error:|ERROR:)' <<<"$first" || return 1
  printf '%s\n' "$first"
}

# A missing or empty log is not a diagnosis. Saying `unknown` here is the honest
# answer and keeps the caller on the fail-closed path — but check stdout first,
# because an empty stderr is exactly the shape an auth failure arrives in.
# Note this no longer short-circuits on an empty stderr: the reviewer's stdout
# may still hold the diagnosis, and it is classified by the same patterns below.

# `ERROR:` at the start of a line is how both CLIs report a failure. Leading
# whitespace is tolerated; an `ERROR:` appearing mid-line is not, because a diff
# quoting one would then count.
errors=$(grep -E '^[[:space:]]*ERROR:' "$log" 2>/dev/null) || errors=""
# A non-empty stderr with no error line of its own does not outrank stdout: the
# CLI logs progress there even when the failure it hit is reported on the other
# stream.
[ -n "$errors" ] || errors=$(stdout_error_line || true)
# Nothing either stream calls an error is not a diagnosis. `unknown` keeps the
# caller on the fail-closed path rather than inventing a cause.
[ -n "$errors" ] || { printf 'unknown\n'; exit 0; }

if grep -qiE 'usage limit|rate limit|quota|too many requests|429' <<<"$errors"; then
  printf 'usage-limit\n'
  exit 0
fi

if grep -qiE '401|403|unauthorized|forbidden|missing bearer|authentication|invalid[^\n]*(token|grant|api key)|expired|revoked' <<<"$errors"; then
  printf 'auth\n'
  exit 0
fi

printf 'unknown\n'
