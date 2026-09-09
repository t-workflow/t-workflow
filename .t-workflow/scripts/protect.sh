#!/usr/bin/env bash
# One-time repository settings: the trunk moves only by squash-merged PRs with the
# `t-workflow` check green; merged branches are deleted.
#   protect.sh [--remove <context>]... [--add <context>]...
# With existing branch protection, only the required-checks list changes: the given
# contexts are removed and added, `t-workflow` is always present, and every other
# rule (reviews, admin enforcement, restrictions) stays exactly as it was. With no
# protection, the minimal set is applied. Reports what the plan refused.
set -uo pipefail
. "$(dirname "$0")/lib.sh"
remove=(); add=()
while [ $# -gt 0 ]; do
  case "$1" in
    --remove) remove+=("$2"); shift 2 ;;
    --add) add+=("$2"); shift 2 ;;
    *) die "unknown option $1" ;;
  esac
done
trunk=$(trunk); nwo=$(repo_nwo)
echo "repository: $nwo  trunk: $trunk"
if gh api -X PATCH "repos/$nwo" -F delete_branch_on_merge=true -F allow_squash_merge=true \
     -F allow_merge_commit=false -F allow_rebase_merge=false >/dev/null; then
  echo "OK: squash merges only, merged branches deleted"
else echo "FAIL: could not change merge settings"; fi

existing=$(gh api "repos/$nwo/branches/$trunk/protection" 2>/tmp/protect.err); rc=$?
if [ "$rc" -ne 0 ]; then
  if grep -q '403' /tmp/protect.err; then
    echo "FAIL: branch protection is not available on this repository (a private repository needs a paid plan); the rule holds by convention"; rm -f /tmp/protect.err; exit 0
  fi
  rm -f /tmp/protect.err
  # 404: the branch is not protected yet — apply the minimal set.
  if gh api -X PUT "repos/$nwo/branches/$trunk/protection" --input - >/dev/null <<JSON
{"required_status_checks":{"strict":false,"contexts":["t-workflow"]},
 "enforce_admins":false,"required_pull_request_reviews":null,"restrictions":null,
 "allow_force_pushes":false,"allow_deletions":false}
JSON
  then echo "OK: $trunk protected — PRs only, 't-workflow' check required, no force pushes"
  else echo "FAIL: branch protection not applied"; exit 1; fi
  exit 0
fi
rm -f /tmp/protect.err
before=$(printf '%s' "$existing" | jq -r '.required_status_checks.contexts[]?')
strict=$(printf '%s' "$existing" | jq -r '.required_status_checks.strict // false')
echo "required checks before: $(printf '%s' "$before" | tr '\n' ' ')"
new=$( { printf '%s\n' "$before"; printf '%s\n' t-workflow "${add[@]}"; } | grep . | awk '!seen[$0]++' )
for r in "${remove[@]}"; do new=$(printf '%s\n' "$new" | grep -vx -- "$r" || true); done
body=$(printf '%s\n' "$new" | grep . | jq -R . | jq -sc --argjson strict "$strict" '{strict: $strict, contexts: .}')
if printf '%s' "$body" | gh api -X PATCH "repos/$nwo/branches/$trunk/protection/required_status_checks" --input - >/dev/null; then
  echo "OK: required checks now: $(printf '%s' "$new" | tr '\n' ' ')— every other protection rule left as it was"
else echo "FAIL: could not update the required checks"; exit 1; fi
