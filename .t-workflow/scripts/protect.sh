#!/usr/bin/env bash
# One-time repository settings: the trunk moves only by squash-merged PRs with the
# `t-workflow` check green; merged branches are deleted. Reports what the plan refused.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
trunk=$(trunk); nwo=$(repo_nwo)
echo "repository: $nwo  trunk: $trunk"
if gh api -X PATCH "repos/$nwo" -F delete_branch_on_merge=true -F allow_squash_merge=true \
     -F allow_merge_commit=false -F allow_rebase_merge=false >/dev/null; then
  echo "OK: squash merges only, merged branches deleted"
else echo "FAIL: could not change merge settings"; fi
if gh api -X PUT "repos/$nwo/branches/$trunk/protection" --input - >/dev/null <<JSON
{"required_status_checks":{"strict":false,"contexts":["t-workflow"]},
 "enforce_admins":false,"required_pull_request_reviews":null,"restrictions":null,
 "allow_force_pushes":false,"allow_deletions":false}
JSON
then echo "OK: $trunk protected — PRs only, 't-workflow' check required, no force pushes"
else echo "FAIL: branch protection not applied (a private repository needs a paid plan for this; the rule then holds by convention)"; fi
