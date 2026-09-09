#!/usr/bin/env bash
# Shared helpers, sourced by the other scripts. Never run directly. bash 3.2 compatible.

# Patterns from config and the built-in sets are matched by glob_match, never expanded
# by the shell against the working directory.
set -f

TW_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TW_DIR="$TW_ROOT/.t-workflow"
TW_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "ERROR: $*" >&2; exit 2; }

# Config, with defaults. Consumer-owned file; keys are documented there.
check=""; protected=""; docs=""; exempt=""; reviewer_model=""
# shellcheck disable=SC1091
[ -f "$TW_DIR/config" ] && . "$TW_DIR/config"

trunk() { "$TW_SCRIPTS/trunk.sh"; }

# slugify <text>: lowercase, non-alphanumerics to '-', trimmed, at most 40 chars.
slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' \
    | cut -c1-40 | sed -E 's/-+$//'
}

# glob_match <path> <pattern>: shell pattern where '*' spans '/'. A pattern naming a
# directory (with or without a trailing '/') matches everything under it.
glob_match() {
  local p="$1" pat="$2"
  pat="${pat//\*\*/*}"
  pat="${pat%/}"
  # shellcheck disable=SC2254
  case "$p" in $pat) return 0 ;; esac
  # shellcheck disable=SC2254
  case "$p" in $pat/*) return 0 ;; esac
  return 1
}

# match_any <path> <pattern>...: 0 when any pattern matches.
match_any() {
  local p="$1" pat; shift
  for pat in "$@"; do glob_match "$p" "$pat" && return 0; done
  return 1
}

# section <heading> < markdown: the body of the first '## <heading>' section.
section() {
  awk -v h="## $1" '
    $0 == h { on = 1; next }
    /^## / { if (on) exit }
    on { print }'
}

# count_sections <heading> < markdown: how many '## <heading>' lines there are.
count_sections() { grep -c "^## $1\$" || true; }

repo_nwo() { gh repo view --json nameWithOwner -q .nameWithOwner; }

# pr_for_task <id> [state]: prints the number of the PR whose head is wip/<id>-*.
# Exit 0 = exactly one, 1 = none, 3 = more than one (all printed).
pr_for_task() {
  local id="$1" state="${2:-open}" nums n
  nums=$(gh pr list --state "$state" --limit 200 --json number,headRefName \
    --jq ".[] | select(.headRefName | test(\"^wip/${id}-\")) | .number")
  n=$(printf '%s\n' "$nums" | grep -c . || true)
  [ "$n" -eq 0 ] && return 1
  printf '%s\n' "$nums"
  [ "$n" -eq 1 ] && return 0
  return 3
}

# blockers_json <id>: [{number,state,stateReason,title}] — GraphQL, since
# `gh issue view --json blockedBy` omits stateReason (needed to tell completed from cancelled).
blockers_json() {
  local nwo; nwo=$(repo_nwo)
  gh api graphql -f query='query($o:String!,$n:String!,$num:Int!){repository(owner:$o,name:$n){issue(number:$num){blockedBy(first:100){nodes{number state stateReason title}}}}}' \
    -F o="${nwo%/*}" -F n="${nwo#*/}" -F num="$1" --jq '.data.repository.issue.blockedBy.nodes'
}

# open_blockers <id>: prints "#n title (state/reason)" for every blocker not closed as
# completed. Exit 0 when none.
open_blockers() {
  blockers_json "$1" | jq -r '.[] | select(.state != "CLOSED" or .stateReason != "COMPLETED")
    | "#\(.number) \(.title) (\(.state)/\(.stateReason // "open"))"' | grep . && return 1
  return 0
}

# review_verdict <reviews-json> <head-committed-at>: reads the latest review and prints
#   verdict: ready|not-ready|none   isolation: <line or none>   fresh: yes|no
# followed by the review's "## Pending human checks" section (or "none"), then its
# medium and low findings ("open-findings:"), which do not block but are restated at the
# merge gate so confirming means the human saw them.
review_verdict() {
  local reviews="$1" head_time="$2" latest body at
  latest=$(printf '%s' "$reviews" | jq -c 'map(select(.body | test("readiness: *(ready|not-ready)"))) | sort_by(.submittedAt) | last // empty')
  if [ -z "$latest" ]; then echo "verdict: none"; echo "isolation: none"; echo "fresh: no"; echo "pending: none"; echo "open-findings: none"; return; fi
  body=$(printf '%s' "$latest" | jq -r .body)
  at=$(printf '%s' "$latest" | jq -r .submittedAt)
  echo "verdict: $(printf '%s' "$body" | grep -oE 'readiness: *(ready|not-ready)' | tail -1 | sed 's/readiness: *//')"
  echo "isolation: $(printf '%s' "$body" | grep -oE '^isolation:.*' | head -1 | sed 's/^isolation: *//' || true)"
  if [ -n "$head_time" ] && [ "$at" \> "$head_time" ]; then echo "fresh: yes"; else echo "fresh: no"; fi
  local pending
  pending=$(printf '%s\n' "$body" | section "Pending human checks" | sed '/^readiness:/,$d' | grep -v '^[[:space:]]*$' || true)
  if [ -z "$pending" ]; then echo "pending: unknown"; else echo "pending:"; printf '%s\n' "$pending" | sed 's/^/  /'; fi
  local findings
  findings=$(printf '%s\n' "$body" | section "Findings" | awk '
    /^### /{ sev = tolower($0); sub(/^### */, "", sev); next }
    (sev == "medium" || sev == "low") && /^- / && tolower($0) !~ /^- *none\.? *$/ { print "  " sev ": " substr($0, 3) }')
  if [ -z "$findings" ]; then echo "open-findings: none"; else echo "open-findings:"; printf '%s\n' "$findings"; fi
}
