#!/usr/bin/env bash
# Which of the given paths are protected (.t-workflow/AGENTS.md §Protected paths, plus
# the `protected` globs in .t-workflow/config). Paths as arguments, or one per line on
# stdin when no arguments are given.
# A protected path needs a cold review. With --plan, the question is instead which
# need a `## Plan`: the built-in set plus `plan_required`, which is `protected` unless
# the config narrows it.
# With --status, stdin is `git diff --name-status -M` output: both paths of a rename are
# judged, and a pure rename (R100) is protected only when either path is in the
# built-in set — moving a file outside it changes nothing a reviewer could judge.
#   exit 0 = at least one protected path (each echoed); 1 = none; 2 = no paths given.
#   --list prints the patterns in force.
set -uo pipefail
. "$(dirname "$0")/lib.sh"

BUILTIN=".t-workflow/AGENTS.md .t-workflow/config .t-workflow/areas.md .t-workflow/scripts .claude .agents .github/workflows AGENTS.md CLAUDE.md GEMINI.md"

# `protected` and `plan_required` arrive via lib.sh's config source, unseen in a
# single-file analysis.
# shellcheck disable=SC2154
extra="$protected"; status=no
# shellcheck disable=SC2154,SC2086
while [ $# -gt 0 ]; do
  case "$1" in
    --plan) [ "$plan_required" = protected ] || extra="$plan_required"; shift ;;
    --status) status=yes; shift ;;
    --list) printf '%s\n' $BUILTIN $extra; exit 0 ;;
    *) break ;;
  esac
done

paths=$(if [ $# -gt 0 ]; then printf '%s\n' "$@"; else cat; fi | grep . || true)
[ -z "$paths" ] && exit 2

hits=0
# shellcheck disable=SC2086
hit() { if match_any "$1" "${@:2}"; then echo "$1"; hits=$((hits + 1)); return 0; fi; return 1; }
if [ "$status" = yes ]; then
  while IFS=$'\t' read -r st a b; do
    case "$st" in
      R100) hit "$b" $BUILTIN || hit "$a" $BUILTIN ;;
      *) hit "$a" $BUILTIN $extra; [ -n "${b:-}" ] && hit "$b" $BUILTIN $extra ;;
    esac
  done <<< "$paths"
else
  while IFS= read -r p; do hit "$p" $BUILTIN $extra; done <<< "$paths"
fi
[ "$hits" -gt 0 ] && exit 0
exit 1
