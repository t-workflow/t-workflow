#!/usr/bin/env bash
# Re-run the t-workflow CI run for a PR's head commit, after a cold review is posted:
# the run that fired on the push was red only because no review existed yet, and
# re-running it is what turns it green — one run per commit, nothing for a human to do.
#   rerun-ci.sh <pr>
#   exit 0 = re-run started, or nothing to do (said why); 1 = the re-run could not be started.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
pr="${1:-}"; [ -n "$pr" ] || { sed -n '2,6p' "$0" | sed 's/^# //'; exit 2; }
head=$(gh pr view "$pr" --json headRefOid -q .headRefOid) || die "cannot read PR #$pr"
run=$(gh run list --workflow t-workflow --limit 50 --json databaseId,headSha,status,conclusion \
  --jq "[.[] | select(.headSha == \"$head\")] | first // empty")
if [ -z "$run" ]; then
  echo "no t-workflow run at $head yet (a draft PR: CI starts when /t-ship marks it ready, and will see the review)"; exit 0
fi
status=$(printf '%s' "$run" | jq -r .status); id=$(printf '%s' "$run" | jq -r .databaseId)
if [ "$status" != completed ]; then echo "run $id at $head is still $status; it will pick up the review when it evaluates"; exit 0; fi
if gh run rerun "$id"; then echo "re-running t-workflow run $id at $head (was $(printf '%s' "$run" | jq -r .conclusion))"
else echo "could not re-run run $id; re-run it from the Actions tab, or push again"; exit 1; fi
