#!/usr/bin/env bash
# Script tests. No network, no gh: everything runs against temporary git repositories.
# This repository's check 1; never shipped to a consumer.
set -uo pipefail
# Fixture commits need an identity; a CI runner has none configured.
export GIT_AUTHOR_NAME=t-workflow GIT_AUTHOR_EMAIL=tests@t-workflow GIT_COMMITTER_NAME=t-workflow GIT_COMMITTER_EMAIL=tests@t-workflow
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
S="$ROOT/.t-workflow/scripts"
pass=0; fail=0
ok()   { pass=$((pass + 1)); }
bad()  { fail=$((fail + 1)); echo "FAIL: $*"; }
expect_exit() { # <expected> <description> <command...>
  local want="$1" what="$2"; shift 2
  local out; out=$("$@" 2>&1); local got=$?
  if [ "$got" -eq "$want" ]; then ok; else bad "$what: exit $got, wanted $want"; printf '%s\n' "$out" | sed 's/^/    /'; fi
}
expect_out() { # <expected substring> <description> <command...>
  local want="$1" what="$2"; shift 2
  local out; out=$("$@" 2>&1)
  if printf '%s' "$out" | grep -qF -- "$want"; then ok; else bad "$what: output lacks '$want'"; printf '%s\n' "$out" | sed 's/^/    /'; fi
}
has() { printf '%s' "$1" | grep -q -- "$2"; }   # has <text> <regex>
sedi() { local n=$# f; f=${!n}; sed -i.bak "$@" && rm -f "$f.bak"; }   # in-place sed, portable, no backup left
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# A consumer-shaped repo to run the scripts in (config from the installer, not this repo's).
mk_repo() { # <dir> [check]
  mkdir -p "$1" && (cd "$1" && git init -q -b main && git commit -q --allow-empty -m init) || return 1
  bash "$ROOT/install.sh" v0.0.0-test --from "$ROOT" --dir "$1" --no-pr >/dev/null 2>&1 || return 1
}

echo "# protected.sh / docs-only.sh"
mk_repo "$tmp/a" || bad "install into a fresh repo"
cd "$tmp/a" || exit
expect_exit 0 "protected: a skill path" "$S/protected.sh" .claude/skills/t-open/SKILL.md
expect_exit 0 "protected: the workflow file" "$S/protected.sh" .github/workflows/t-workflow.yml
expect_exit 1 "protected: app code is not" "$S/protected.sh" src/app.rb
expect_exit 1 "protected: config is not" "$S/protected.sh" .t-workflow/config
expect_exit 2 "protected: no input" bash -c "$S/protected.sh </dev/null"
expect_out ".claude/skills/t-open/SKILL.md" "protected: echoes the hit" "$S/protected.sh" src/x .claude/skills/t-open/SKILL.md
sedi 's|^protected=""|protected="db/migrate/* config/credentials"|' .t-workflow/config
expect_exit 0 "protected: config glob with *" "$S/protected.sh" db/migrate/001_init.rb
expect_exit 0 "protected: config directory pattern matches beneath" "$S/protected.sh" config/credentials/prod.yml
expect_exit 1 "protected: sibling of a config pattern" "$S/protected.sh" config/routes.rb
expect_exit 0 "docs-only: markdown and docs/" bash -c "printf 'README.md\ndocs/a/b.txt\n' | $S/docs-only.sh"
expect_exit 1 "docs-only: one source file" bash -c "printf 'README.md\nsrc/a.c\n' | $S/docs-only.sh"
expect_exit 2 "docs-only: no input" bash -c "printf '' | $S/docs-only.sh"
sedi 's|^docs=""|docs="site/*"|' .t-workflow/config
expect_exit 0 "docs-only: config glob" "$S/docs-only.sh" site/index.html
expect_exit 1 "docs-only: shell globbing must not expand *.md against the cwd" "$S/docs-only.sh" AGENTS.txt

echo "# trunk.sh"
expect_out "main" "trunk: local main" "$S/trunk.sh"
(cd "$tmp" && git init -q -b master t && cd t && git commit -q --allow-empty -m i) && expect_out "master" "trunk: local master" bash -c "cd $tmp/t && $S/trunk.sh"
git -C "$tmp/a" remote add origin "$tmp/t" && git -C "$tmp/a" fetch -q origin && git -C "$tmp/a" remote set-head origin master
expect_out "master" "trunk: origin HEAD wins" bash -c "cd $tmp/a && $S/trunk.sh"

echo "# record.sh check"
cd "$tmp/a" || exit; mkdir -p docs/tasks
cat > docs/tasks/7-fixture.md <<'R'
# 7 — Fixture
Issue: #7

## Asked
Do the thing.

## Done when
It is done.

## Explicitly not
none

## Decisions made along the way
- none

## Deviations / notes
- none
R
expect_exit 0 "record: valid" "$S/record.sh" check 7
expect_out "docs/tasks/7-fixture.md" "record: path" "$S/record.sh" path 7
expect_exit 1 "record: missing" "$S/record.sh" check 8
sedi 's/^Do the thing./<the goal, from the issue>/' docs/tasks/7-fixture.md
expect_out "placeholder" "record: unfilled placeholder" "$S/record.sh" check 7
sedi 's/^## Asked$/## Ask/' docs/tasks/7-fixture.md
expect_out "missing '## Asked'" "record: missing section" "$S/record.sh" check 7
printf '# 9 — Wrong id\nIssue: #9\n' > docs/tasks/7-other.md
expect_out "first line" "record: id mismatch" "$S/record.sh" check 7 docs/tasks/7-other.md
printf '# 7 — Fixture\nIssue: #7\n\n## Asked\nDo it.\n\n## Asked\nTwice.\n\n## Done when\nDone.\n\n## Explicitly not\nnone\n\n## Decisions made along the way\n- none\n\n## Deviations / notes\n- none\n' > docs/tasks/7-dup.md
expect_out "duplicated '## Asked'" "record: duplicated section" "$S/record.sh" check 7 docs/tasks/7-dup.md
printf '# 7 — Fixture\nIssue: #7\n\n## Done when\nDone.\n\n## Asked\nDo it.\n\n## Explicitly not\nnone\n\n## Decisions made along the way\n- none\n\n## Deviations / notes\n- none\n' > docs/tasks/7-order.md
expect_out "out of order" "record: out-of-order section" "$S/record.sh" check 7 docs/tasks/7-order.md
printf '# 7 — Fixture\nIssue: #7\n\n## Asked\n<from the issue>\n\n## Done when\nDone.\n\n## Explicitly not\nnone\n\n## Decisions made along the way\n- none\n\n## Deviations / notes\n- none\n' > docs/tasks/7-place.md
expect_out "template placeholder" "record: placeholder-only section" "$S/record.sh" check 7 docs/tasks/7-place.md
printf '# 7 — Fixture\nIssue: #7\n\n## Asked\n\n## Done when\nDone.\n\n## Explicitly not\nnone\n\n## Decisions made along the way\n- none\n\n## Deviations / notes\n- none\n' > docs/tasks/7-empty.md
expect_out "'## Asked' section is empty" "record: empty section" "$S/record.sh" check 7 docs/tasks/7-empty.md

echo "# record.sh: '## Agents' — absent is legacy, present must carry real entries"
cat > docs/tasks/20-legacy.md <<'R'
# 20 — Legacy
Issue: #20

## Asked
A.

## Done when
B.

## Explicitly not
none

## Decisions made along the way
- none

## Deviations / notes
- none
R
expect_exit 0 "record: legacy record with no '## Agents' section still passes" "$S/record.sh" check 20 docs/tasks/20-legacy.md
out=$("$S/record.sh" trailers 20); [ -z "$out" ] && ok || bad "record: trailers of a legacy record with no section is silent: $out"

cat > docs/tasks/21-fresh.md <<'R'
# 21 — Fresh
Issue: #21

## Asked
A.

## Done when
B.

## Explicitly not
none

## Decisions made along the way
- none

## Deviations / notes
- none

## Agents
R
expect_out "'## Agents' section has no entries" "record: create's fresh empty section fails until a stage appends" "$S/record.sh" check 21 docs/tasks/21-fresh.md
"$S/record.sh" agent 21 plan claude-code claude-fable-5-1 > /dev/null
expect_exit 0 "record: check passes once a stage appends an entry" "$S/record.sh" check 21 docs/tasks/21-fresh.md
"$S/record.sh" agent 21 review claude-code claude-opus-5 "subagent, reviewer_model" > /dev/null
"$S/record.sh" agent 21 work claude-code claude-fable-5-1 > /dev/null
has "$(cat docs/tasks/21-fresh.md)" '^- plan: claude-code / claude-fable-5-1$' && ok || bad "record: agent appends 'plan' line"
has "$(cat docs/tasks/21-fresh.md)" '^- review: claude-code / claude-opus-5 (subagent, reviewer_model)$' && ok || bad "record: agent appends 'review' line with its note"
expect_exit 0 "record: check still passes with several entries" "$S/record.sh" check 21 docs/tasks/21-fresh.md
out=$("$S/record.sh" trailers 21)
[ "$out" = "$(printf 'Planned-By: claude-code / claude-fable-5-1\nImplemented-By: claude-code / claude-fable-5-1')" ] && ok || bad "record: trailers map plan/work, skip review (stale in the record): $out"
"$S/record.sh" agent 21 "work (fix)" claude-code claude-opus-5 > /dev/null
out=$("$S/record.sh" trailers 21)
has "$out" '^Implemented-By: claude-code / claude-opus-5$' && ok || bad "record: trailers list one Implemented-By per work pass: $out"

printf '# 22 — Dup\nIssue: #22\n\n## Asked\nA.\n\n## Done when\nB.\n\n## Explicitly not\nnone\n\n## Decisions made along the way\n- none\n\n## Deviations / notes\n- none\n\n## Agents\n- plan: x / y\n\n## Agents\n- work: x / y\n' > docs/tasks/22-dup.md
expect_out "duplicated '## Agents' section" "record: duplicated Agents section" "$S/record.sh" check 22 docs/tasks/22-dup.md
rm -f docs/tasks/20-legacy.md docs/tasks/21-fresh.md docs/tasks/22-dup.md

echo "# lib.sh helpers"
# shellcheck disable=SC1091
. "$S/lib.sh"
[ "$(slugify 'Add /t-config: a Skill!! ')" = "add-t-config-a-skill" ] && ok || bad "slugify"
[ "$(slugify "$(printf '%60s' '' | tr ' ' x)")" = "$(printf '%40s' '' | tr ' ' x)" ] && ok || bad "slugify truncates to 40"
printf '## A\none\n## Plan\nallowed\n\n## B\nb\n' | section Plan | grep -q '^allowed$' && ok || bad "section extracts a body"
[ "$(printf '## Plan\n## Plan\n' | count_sections Plan)" = 2 ] && ok || bad "count_sections"
reviews='[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: subagent\n## Pending human checks\n- none\nreadiness: ready"},{"submittedAt":"2026-01-02T00:00:00Z","body":"isolation: fresh session\nreadiness: not-ready"}]'
rvp=$(review_verdict '[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: subagent\n## Findings\n- x\n## Pending human checks\n- check the colours\nreadiness: ready"}]' "")
has "$rvp" '^  - check the colours$' && ok || bad "review_verdict: pending checks listed"
printf '%s' "$rvp" | grep -q 'readiness' && bad "review_verdict: readiness line leaks into pending checks" || ok
rv0=$(review_verdict '[]' "")
# a CRLF body must yield exactly what the LF body yields
lfbody='isolation: fresh session\n## Findings\n### Medium\n- m at x:1\n### Low\n- none\n## Pending human checks\n- p\nreadiness: ready\n'
crlfbody=$(printf '%s' "$lfbody" | sed 's/\\n/\\r\\n/g')
lf=$(review_verdict "[{\"submittedAt\":\"2026-01-01T00:00:00Z\",\"body\":\"$lfbody\"}]" ""); cr=$(review_verdict "[{\"submittedAt\":\"2026-01-01T00:00:00Z\",\"body\":\"$crlfbody\"}]" "")
[ "$lf" = "$cr" ] && has "$lf" '^  medium: m at x:1$' && has "$lf" '^isolation: fresh session$' && ok || bad "review_verdict: CRLF and LF bodies differ:\n$lf\n---\n$cr"
printf '%s' "$cr" | grep -q $'\r' && bad "review_verdict: a carriage return leaked into the output" || ok
nof=$(review_verdict '[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: subagent\n## Pending human checks\n- none\nreadiness: ready"}]' "")
has "$nof" '^open-findings: unknown$' && ok || bad "review_verdict: a review with no Findings section is unknown, not none: $nof"
crlf=$(review_verdict '[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: fresh session\r\n## Findings\r\n### Medium \r\n- (none)\r\n- typed on the web at c.md:2\r\n### Low\r\n- none\r\n## Pending human checks\r\n- try it on a phone\r\nreadiness: ready\r\n"}]' "")
has "$crlf" '^  medium: typed on the web at c.md:2' && ok || bad "review_verdict: CRLF body and a trailing space on the heading still yield the findings: $crlf"
has "$crlf" '^  - try it on a phone' && ok || bad "review_verdict: CRLF body still yields pending checks: $crlf"
printf '%s' "$crlf" | grep -q '(none)' && bad "review_verdict: '- (none)' is not a finding" || ok
rvf=$(review_verdict '[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: subagent\n## Checks\n- ran: x\n## Findings\n### High\n- broken thing at a.sh:3\n### Medium\n- odd wording at b.md:1\n### Low\n- none\n- nit one\n- nit two\n## Pending human checks\n- none\nreadiness: not-ready"}]' "")
has "$rvf" '^  medium: odd wording at b.md:1$' && has "$rvf" '^  low: nit two$' && ok || bad "review_verdict: lists medium and low findings: $rvf"
printf '%s' "$rvf" | grep -q 'broken thing' && bad "review_verdict: a high finding is not an open finding (it blocks instead)" || ok
printf '%s' "$rvf" | grep -q 'low: none' && bad "review_verdict: a '- none' entry is not a finding" || ok
has "$rv0" '^open-findings: none$' && ok || bad "review_verdict: no review means no open findings"
rv=$(review_verdict "$reviews" "2026-01-01T12:00:00Z"); rv3=$(review_verdict "$reviews" "2026-01-03T00:00:00Z")
has "$rv" '^verdict: not-ready$' && ok || bad "review_verdict: latest wins"
has "$rv3" '^fresh: no$' && ok || bad "review_verdict: stale when head is newer"
has "$rv" '^fresh: yes$' && ok || bad "review_verdict: fresh"
has "$rv" '^pending: unknown$' && ok || bad "review_verdict: missing pending section is unknown"
has "$rv0" '^verdict: none$' && ok || bad "review_verdict: none"
has "$rv0" '^agent: none$' && ok || bad "review_verdict: agent is 'none' when there is no review"
rvm=$(review_verdict '[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: subagent\nmodel: claude-code / claude-opus-5\n## Pending human checks\n- none\nreadiness: ready"}]' "")
has "$rvm" '^agent: claude-code / claude-opus-5$' && ok || bad "review_verdict: agent reads the review's 'model:' line: $rvm"
has "$rvp" '^agent: $' && ok || bad "review_verdict: agent is blank, not missing, when the review has no 'model:' line: $rvp"

echo "# review_blocks (the ship gate's review rules)"
rb() { printf '%s\n' "$2" | review_blocks "$1" 9 2>&1; }
ready='verdict: ready\nisolation: subagent\nfresh: yes\npending:\n  - none\nopen-findings: none'
out=$(rb yes "$(printf "$ready")") && [ -z "$out" ] && ok || bad "review_blocks: a fresh ready review passes a protected diff: $out"
out=$(rb yes "$(printf 'verdict: none\nisolation: none\nfresh: no\npending: none\nopen-findings: none')"); has "$out" 'no cold review' && ok || bad "review_blocks: protected with no review blocks: $out"
out=$(rb no "$(printf 'verdict: none\nisolation: none\nfresh: no\npending: none\nopen-findings: none')") && [ -z "$out" ] && ok || bad "review_blocks: unprotected with no review passes: $out"
out=$(rb no "$(printf "$ready" | sed 's/ready/not-ready/')"); has "$out" 'not-ready' && ok || bad "review_blocks: not-ready blocks even unprotected: $out"
out=$(rb yes "$(printf "$ready" | sed 's/fresh: yes/fresh: no/')"); has "$out" 'older than the head' && ok || bad "review_blocks: stale review blocks protected: $out"
out=$(rb no "$(printf "$ready" | sed 's/fresh: yes/fresh: no/')") && has "$out" '^note: the ready review predates' && ok || bad "review_blocks: stale review is a note when unprotected: $out"
out=$(rb yes "$(printf "$ready" | sed 's/isolation: subagent/isolation: same session (tiny)/')"); has "$out" 'same session' && ok || bad "review_blocks: same-session blocks protected: $out"
out=$(rb no "$(printf "$ready" | sed 's/isolation: subagent/isolation: same session (tiny)/')") && [ -z "$out" ] && ok || bad "review_blocks: same-session passes unprotected: $out"
out=$(rb no "$(printf "$ready" | sed '/^pending:/,/^  - none/d; s/^open-findings/pending: unknown\nopen-findings/')"); has "$out" 'no .## Pending human checks. section' && ok || bad "review_blocks: unknown pending blocks: $out"
out=$(rb no "$(printf "$ready" | sed 's/open-findings: none/open-findings: unknown/')"); has "$out" 'no .## Findings. section' && ok || bad "review_blocks: unknown findings block: $out"
out=$(rb yes "$(printf 'verdict: none\nisolation: none\nfresh: no\npending: unknown\nopen-findings: unknown')"); printf '%s' "$out" | grep -q 'section' && bad "review_blocks: unknown sections do not apply when there is no review" || ok
u=$("$S/gate.sh" 2>&1); has "$u" 'exit 0 = proceed' && ! has "$u" 'set -uo' && ok || bad "gate.sh: usage prints the whole header and nothing else: $u"
echo "# bodies are normalised at entry"
printf '# 7 — X\r\nIssue: #7\r\n\r\n## Asked\r\nA.\r\n\r\n## Done when\r\nB.\r\n\r\n## Explicitly not\r\nnone\r\n\r\n## Decisions made along the way\r\n- none\r\n\r\n## Deviations / notes\r\n- none\r\n' > "$tmp/a/docs/tasks/7-crlf.md"
[ "$(printf '## Plan\r\n## Plan \r\n' | count_sections Plan)" = 2 ] && ok || bad "count_sections: CRLF headings counted"
[ "$(printf '## A\r\nx  \r\n' | normalize | od -c | grep -c '\\r')" = 0 ] && ok || bad "normalize strips carriage returns"

echo "# install.sh"
mk_repo "$tmp/b" && ok || bad "install: adopt"
cd "$tmp/b" || exit
[ "$(cat .t-workflow/VERSION)" = v0.0.0-test ] && ok || bad "install: VERSION"
[ -L CLAUDE.md ] && [ -L GEMINI.md ] && [ -L .agents/skills ] && ok || bad "install: symlinks"
grep -q '^check=""' .t-workflow/config && ok || bad "install: pristine config, not this repo's"
head -1 AGENTS.md | grep -q '.t-workflow/AGENTS.md' && ok || bad "install: AGENTS.md pointer"
for p in .t-workflow/scripts/gate.sh .claude/skills/t-work/SKILL.md .github/workflows/t-workflow.yml docs/tasks/TEMPLATE.md; do [ -e "$p" ] || bad "install: missing $p"; done; ok
[ -e .github/ISSUE_TEMPLATE/task.yml ] && bad "install: the retired issue form was written" || ok
[ ! -e tests ] && [ ! -e install.sh ] && [ ! -e CHANGELOG.md ] && ok || bad "install: repo-only files leaked"
[ ! -e .github/workflows/build.yml ] && ok || bad "install: adopt writes no build workflow"
# a real CLAUDE.md becomes AGENTS.md with the pointer prepended
mkdir -p "$tmp/c" && (cd "$tmp/c" && git init -q -b main && printf '# App\nDo X.\n' > CLAUDE.md && echo '{}' > package.json && git add -A && git commit -qm i)
bash "$ROOT/install.sh" v1 --from "$ROOT" --dir "$tmp/c" --no-pr >/dev/null 2>&1 || bad "install: with CLAUDE.md"
grep -q '^Do X.$' "$tmp/c/AGENTS.md" && head -1 "$tmp/c/AGENTS.md" | grep -q t-workflow && [ -L "$tmp/c/CLAUDE.md" ] && ok || bad "install: CLAUDE.md content kept under the pointer"
grep -q '^check="npm test"' "$tmp/c/.t-workflow/config" && ok || bad "install: check detected from package.json"
(cd "$tmp/c" && git add -A && git commit -qm installed-v1) >/dev/null 2>&1
out=$(bash "$ROOT/install.sh" v1 --from "$ROOT" --dir "$tmp/c" --no-pr 2>&1); has "$out" "already at v1" && ok || bad "install: same tag is a no-op"
# update keeps consumer-owned files, replaces owned ones
(cd "$tmp/c" && echo 'hand edit' >> .claude/skills/t-open/SKILL.md && sedi 's/^check=.*/check="mine"/' .t-workflow/config && echo "mine" >> AGENTS.md && git add -A && git commit -qm c)
(cd "$tmp/c" && grep -v '^exempt=' .t-workflow/config > cfg && printf '%s' "$(< cfg)" > .t-workflow/config && git add -A && git commit -qm "drop a key")
out=$(bash "$ROOT/install.sh" v2 --from "$ROOT" --dir "$tmp/c" --no-pr 2>&1) || bad "install: update: $out"
(cd "$tmp/c" && [ "$(cat .t-workflow/VERSION)" = v2 ] && grep -q '^check="mine"' .t-workflow/config && grep -q '^mine$' AGENTS.md && ! grep -q 'hand edit' .claude/skills/t-open/SKILL.md) && ok || bad "install: update replaced owned files and kept consumer ones"
(cd "$tmp/c" && grep -q '^exempt=""' .t-workflow/config && grep -B1 '^exempt=""' .t-workflow/config | head -1 | grep -q '^# Branch globs') && has "$out" 'config: added exempt' && ok || bad "install: update appends a missing config key with its comment"
[ "$(grep -c '^check=' "$tmp/c/.t-workflow/config")" = 1 ] && ok || bad "install: update does not duplicate present keys"
(cd "$tmp/c" && sed -i.bak 's|^# Build/test command the agent runs locally.*|# Build/test command, run as check 1 (empty = no check 1 yet).|; /^# CI does not run it/d; s|^# Branch globs exempt.*|# Branch globs exempt from the task gates in CI (e.g. "dependabot/*"). Check 1 still runs.|; s|^# Parsed by .t-workflow/scripts/\*.*|# Shell syntax: key="value". Read by .t-workflow/scripts/*.|; /^# inside the value, no variables/d' .t-workflow/config && rm -f .t-workflow/config.bak && git add -A && git commit -qm "old comments")
bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/c" --no-pr >/dev/null 2>&1 || bad "install: update (comments)"
(cd "$tmp/c" && grep -q '^# CI does not run it' .t-workflow/config && ! grep -q 'Check 1 still runs' .t-workflow/config && grep -q '^check="mine"' .t-workflow/config) && ok || bad "install: update rewrites the old default comments and keeps the values: $(grep -E '^#|^check=' "$tmp/c/.t-workflow/config" | head -8)"
(cd "$tmp/c" && grep -q '^# Parsed by .t-workflow/scripts/\*, never executed' .t-workflow/config && grep -q '^# inside the value, no variables' .t-workflow/config && ! grep -q '^# Shell syntax' .t-workflow/config) && ok || bad "install: update rewrites the old 'shell syntax' header to the parsed-not-executed one: $(head -3 "$tmp/c/.t-workflow/config")"
# a retired owned file: removed on update only when it is byte-for-byte a copy this repository shipped
mkdir -p "$tmp/c/.github/ISSUE_TEMPLATE" && cat > "$tmp/c/.github/ISSUE_TEMPLATE/task.yml" <<'FORM'
name: Task
description: A single piece of work for the t-workflow pipeline.
body:
  - type: textarea
    id: goal
    attributes:
      label: Goal
      description: What should change and why.
    validations:
      required: true
  - type: textarea
    id: done-when
    attributes:
      label: Done when
      description: Observable criteria that say the work is finished.
    validations:
      required: true
  - type: textarea
    id: scope
    attributes:
      label: Scope
      description: Paths the work may touch.
    validations:
      required: true
  - type: textarea
    id: non-goals
    attributes:
      label: Non-goals
      description: What this task explicitly does not do.
    validations:
      required: true
FORM
[ "$(git hash-object "$tmp/c/.github/ISSUE_TEMPLATE/task.yml")" = b774760dd3dad869983e021d21693afecd191646 ] && ok || bad "install: the fixture is not the form the trunk carried before #34 (blob $(git hash-object "$tmp/c/.github/ISSUE_TEMPLATE/task.yml"))"
(cd "$tmp/c" && git add -A && git commit -qm "the old form")
out=$(bash "$ROOT/install.sh" v4 --from "$ROOT" --dir "$tmp/c" --no-pr 2>&1) || bad "install: update (retired form): $out"
[ ! -e "$tmp/c/.github/ISSUE_TEMPLATE/task.yml" ] && has "$out" 'remove: .github/ISSUE_TEMPLATE/task.yml (retired' && ok || bad "install: update removes the release's own copy of a retired file: $out"
mkdir -p "$tmp/c/.github/ISSUE_TEMPLATE" && printf 'name: Task\nbody: mine\n' > "$tmp/c/.github/ISSUE_TEMPLATE/task.yml" && (cd "$tmp/c" && git add -A && git commit -qm "my own form")
out=$(bash "$ROOT/install.sh" v5 --from "$ROOT" --dir "$tmp/c" --no-pr 2>&1) || bad "install: update (consumer form): $out"
[ "$(cat "$tmp/c/.github/ISSUE_TEMPLATE/task.yml")" = "$(printf 'name: Task\nbody: mine')" ] && has "$out" 'remove: (none)' && has "$out" 'stays yours' && ok || bad "install: update leaves a consumer's own file at a retired path: $out"
(cd "$tmp/c" && grep -B1 '^# Branch globs' .t-workflow/config | head -1 | grep -q '^$') && ok || bad "install: appended key is separated by a blank line even when the config lacked a trailing newline"
# a dirty tree refuses in every mode, even with --no-pr; the plan prints first
mkdir -p "$tmp/dirty" && (cd "$tmp/dirty" && git init -q -b main && git commit -q --allow-empty -m i && echo dirty > untracked.txt)
out=$(bash "$ROOT/install.sh" v1 --from "$ROOT" --dir "$tmp/dirty" --no-pr 2>&1); rc=$?
[ "$rc" -ne 0 ] && has "$out" 'not clean' && ok || bad "install: a dirty tree refuses in adopt mode (exit $rc): $out"
rm "$tmp/dirty/untracked.txt"
out=$(bash "$ROOT/install.sh" v1 --from "$ROOT" --dir "$tmp/dirty" --no-pr 2>&1) || bad "install: plan fixture: $out"
has "$out" 'plan:' && has "$out" 'write:' && has "$out" 'settings:' && has "$out" '.t-workflow/scripts' && ok || bad "install: the plan lists writes and settings before changing anything: $out"
(cd "$tmp/dirty" && git add -A && git commit -qm installed-v1) >/dev/null 2>&1
echo dirty > "$tmp/dirty/untracked.txt"
out=$(bash "$ROOT/install.sh" v2 --from "$ROOT" --dir "$tmp/dirty" --no-pr 2>&1); rc=$?
[ "$rc" -ne 0 ] && has "$out" 'not clean' && ok || bad "install: a dirty tree refuses in update mode (exit $rc): $out"
# adopt mode refuses a colliding owned path and lists it; the aliases still merge
mkdir -p "$tmp/collide/.github/workflows" && (cd "$tmp/collide" && git init -q -b main && mkdir -p .claude/skills/t-open && echo mine > .claude/skills/t-open/SKILL.md && git add -A && git commit -qm i)
out=$(bash "$ROOT/install.sh" v1 --from "$ROOT" --dir "$tmp/collide" --no-pr 2>&1); rc=$?
[ "$rc" -ne 0 ] && has "$out" 'refusing to overwrite' && has "$out" '.claude/skills/t-open' && ok || bad "install: adopt refuses a colliding path and lists it (exit $rc): $out"
[ "$(cat "$tmp/collide/.claude/skills/t-open/SKILL.md")" = mine ] && ok || bad "install: a refused run changes nothing"
# a git source: no tag means the newest tag; a tag means that tag
git clone -q --bare "$ROOT" "$tmp/src.git" && git -C "$tmp/src.git" tag v9.9.1 && git -C "$tmp/src.git" tag v9.9.10 && git -C "$tmp/src.git" tag v9.9.2 && git -C "$tmp/src.git" tag rel/v9.9.3
mkdir -p "$tmp/f" && (cd "$tmp/f" && git init -q -b main && git commit -q --allow-empty -m i)
out=$(bash "$ROOT/install.sh" --from "file://$tmp/src.git" --dir "$tmp/f" --no-pr 2>&1) || bad "install: git source, no tag: $out"
[ "$(cat "$tmp/f/.t-workflow/VERSION")" = v9.9.10 ] && ok || bad "install: newest tag by version order, got $(cat "$tmp/f/.t-workflow/VERSION")"
git -C "$tmp/src.git" tag zz-unrelated
mkdir -p "$tmp/f2" && (cd "$tmp/f2" && git init -q -b main && git commit -q --allow-empty -m i)
out=$(bash "$ROOT/install.sh" --from "file://$tmp/src.git" --dir "$tmp/f2" --no-pr 2>&1) || bad "install: git source with an unrelated tag: $out"
[ "$(cat "$tmp/f2/.t-workflow/VERSION")" = v9.9.10 ] && ok || bad "install: an unrelated tag never wins, got $(cat "$tmp/f2/.t-workflow/VERSION")"
(cd "$tmp/f" && git add -A && git commit -qm installed-v9.9.10) >/dev/null 2>&1
out=$(bash "$ROOT/install.sh" v9.9.2 --from "file://$tmp/src.git" --dir "$tmp/f" --no-pr 2>&1) || bad "install: git source, explicit tag: $out"
[ "$(cat "$tmp/f/.t-workflow/VERSION")" = v9.9.2 ] && has "$out" 'changes from v9.9.10 to v9.9.2' && ok || bad "install: explicit tag and log between tags"
(cd "$tmp/f" && git add -A && git commit -qm installed-v9.9.2) >/dev/null 2>&1
out=$(bash "$ROOT/install.sh" rel/v9.9.3 --from "file://$tmp/src.git" --dir "$tmp/f" --no-pr 2>&1) || bad "install: tag with a slash: $out"
[ "$(cat "$tmp/f/.t-workflow/VERSION")" = rel/v9.9.3 ] && ok || bad "install: a tag containing / is kept whole, got $(cat "$tmp/f/.t-workflow/VERSION")"
out=$(bash "$ROOT/install.sh" --from "$ROOT" --dir "$tmp/f" --no-pr 2>&1); has "$out" 'a tag is required' && ok || bad "install: local directory needs a tag"
out=$(bash "$ROOT/install.sh" --from "file://$tmp/nowhere.git" --dir "$tmp/f" --no-pr 2>&1); has "$out" 'could not list tags' && ok || bad "install: unreachable source reports the real failure, not 'no tags': $out"
# replace: the old template layout with a manifest and filled slots
mkdir -p "$tmp/d/.github/workflows" "$tmp/d/.claude/skills/t-config" "$tmp/d/.claude/skills/l-mine" "$tmp/d/.t-workflow/scripts" "$tmp/d/migrations" "$tmp/d/docs/adr" "$tmp/d/docs/tasks/000100"
cd "$tmp/d" && git init -q -b main
printf '# AGENTS.md\n\n## The pipeline\n<!-- local -->\nConsumer skills, see docs/skills.md.\n\n| Skill | Stage |\n|---|---|\n| `/l-mine` | Does my thing. |\n<!-- /local -->\n## Reviewer model\n<!-- local -->\nDefault reviewer model: opus\n<!-- /local -->\n## Checks\n<!-- local -->\n1. `make test` — the build\n<!-- /local -->\n### Documentation-only paths\n<!-- local -->\n- `site/**`\n<!-- /local -->\n## Project notes\n<!-- local -->\nUse rubocop.\n<!-- /local -->\n' > AGENTS.md
printf '# CONSTITUTION.md\n<!-- local -->\n**Status note:** phase 0.\n<!-- /local -->\n## 3. Protected surfaces\n- `docs/adr/`\n<!-- local -->\n- `db/migrate/`\n<!-- /local -->\n## 4. Stack & architecture\n<!-- local -->\n- Rails only.\n<!-- /local -->\n' > CONSTITUTION.md
printf 'node_modules\n# <!-- local -->\n.env\n# <!-- /local -->\n' > .gitignore
echo old > .claude/skills/t-config/SKILL.md; echo mine > .claude/skills/l-mine/SKILL.md; echo old > .t-workflow/scripts/x.sh
printf 'name: CI\n# <!-- local -->\n      - uses: actions/setup-java@v4\n        if: "!cancelled()"\n        with:\n          java-version: 21\n      - run: make lint\n      # the manifest lock, an old-template step\n      - name: Template-owned files match the pinned manifest\n        if: "!cancelled()"\n        run: ./.t-workflow/scripts/check-manifest.sh\n# a column-zero comment\n      - name: Build\n        if: "!cancelled() && steps.docs-only.outputs.docs_only != '"'"'true'"'"'"\n        run: make test\n      # a trailing note\n# <!-- /local -->\n' > .github/workflows/ci.yml
echo v1 > migrations/V1__x.md; echo adr > docs/adr/001-old.md; echo mine > docs/adr/100-mine.md; echo rec > docs/tasks/000100/101-x.md; echo t > docs/tasks/TEMPLATE.md
ln -s AGENTS.md CLAUDE.md; mkdir -p .agents && ln -s ../.claude/skills .agents/skills
printf '{"files":{"AGENTS.md":{},"CONSTITUTION.md":{},".gitignore":{},".claude/skills/t-config/SKILL.md":{},".t-workflow/scripts/x.sh":{},".github/workflows/ci.yml":{},"docs/adr/001-old.md":{},"docs/tasks/TEMPLATE.md":{},"CLAUDE.md":{},".agents/skills":{}}}' > .template-manifest.json
git add -A && git commit -qm old
bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/d" --no-pr >/dev/null 2>&1 || bad "install: replace"
[ ! -e .template-manifest.json ] && [ ! -e migrations ] && [ ! -e CONSTITUTION.md ] && [ ! -e .github/workflows/ci.yml ] && [ ! -e docs/adr/001-old.md ] && [ ! -e .claude/skills/t-config ] && ok || bad "replace: old files removed"
[ -f docs/adr/100-mine.md ] && [ -f docs/tasks/000100/101-x.md ] && [ -f .claude/skills/l-mine/SKILL.md ] && ok || bad "replace: consumer files kept"
grep -q '^check="make test"' .t-workflow/config && grep -q '^protected="db/migrate/"' .t-workflow/config && grep -q '^docs="site/\*\*"' .t-workflow/config && grep -q '^reviewer_model="opus"' .t-workflow/config && ok || bad "replace: slots into config: $(grep -vE '^#|^$' .t-workflow/config | tr '\n' ' ')"
grep -q '^Use rubocop.$' AGENTS.md && grep -q '^- Rails only.$' AGENTS.md && ok || bad "replace: notes and constraints into AGENTS.md"
grep -q '^## Skills of this repository$' AGENTS.md && grep -q '^| `/l-mine` | Does my thing. |$' AGENTS.md && ok || bad "replace: consumer skill rows into AGENTS.md: $(grep -A3 'Skills of' AGENTS.md)"
grep -q '^\.env$' .gitignore && ! grep -q 'local -->' .gitignore && ok || bad "replace: gitignore kept, markers stripped"
[ "$(grep -c '^## ' .t-workflow/REPLACED.md)" = 2 ] && grep -q 'CONSTITUTION.md' .t-workflow/REPLACED.md && grep -q 'beside the skill rows' .t-workflow/REPLACED.md && grep -q 'see docs/skills.md' .t-workflow/REPLACED.md && ! grep -q 'make lint' .t-workflow/REPLACED.md && ok || bad "replace: the status note and the text beside the skill rows are reported, nothing else: $(grep '^## ' .t-workflow/REPLACED.md | tr '\n' ';')"
grep -q '^      # a trailing note$' .github/workflows/build.yml && ok || bad "replace: a trailing comment in the slot is kept"
b=.github/workflows/build.yml
grep -q '^      - uses: actions/checkout@v4$' $b && grep -q '^      - uses: actions/setup-java@v4$' $b && grep -q '^          java-version: 21$' $b && grep -q '^      - run: make lint$' $b && grep -q '^        run: make test$' $b && grep -q '^    branches: \[main\]$' $b && ok || bad "replace: build.yml written from the ci slot: $(cat $b)"
grep -q '^      # a column-zero comment$' $b && ok || bad "replace: a column-zero comment in the slot is indented, not mangled: $(grep -n comment $b)"
! grep -q 'check-manifest' $b && ! grep -q 'manifest lock' $b && grep -q '^      - name: Build$' $b && ok || bad "replace: a step running an old script is dropped with its comment, the rest kept: $(grep -nE 'manifest|Build' $b)"
grep -A2 '^      - uses: actions/checkout@v4$' $b | grep -q '^          fetch-depth: 0$' && ok || bad "replace: the generated checkout has full depth"
grep -q "if: \"!cancelled()\"$" $b && ! grep -q 'docs-only' $b && ok || bad "replace: the old docs-only output reference is dropped from if: lines: $(grep 'if:' $b)"
[ "$(grep -cE '^(name|on|jobs):' $b)" = 3 ] && ok || bad "replace: build.yml has name, on, jobs"
[ -L CLAUDE.md ] && [ -L .agents/skills ] && ok || bad "replace: aliases restored"
(cd "$tmp/d" && git add -A && git commit -qm installed-v3) >/dev/null 2>&1
printf '{"files":{}}' > .template-manifest.json
(cd "$tmp/d" && git add -A && git commit -qm empty-manifest) >/dev/null 2>&1
out=$(bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/d" --no-pr 2>&1); has "$out" "lists no files" && ok || bad "replace: refuses an empty manifest"
# the old bootstrap's shape: no manifest, every slot a placeholder, the old files by name
mkdir -p "$tmp/g/.github/workflows" "$tmp/g/.github/ISSUE_TEMPLATE" "$tmp/g/.claude/skills/t-config" "$tmp/g/.claude/skills/t-work" "$tmp/g/.claude/skills/l-mine" "$tmp/g/.t-workflow/scripts" "$tmp/g/migrations" "$tmp/g/docs/adr" "$tmp/g/docs/adapters" "$tmp/g/docs/architecture" "$tmp/g/docs/tasks/000000" "$tmp/g/docs/own"
cd "$tmp/g" && git init -q -b main
printf '# AGENTS.md\n\n## The pipeline\n<!-- local -->\n*(reserved: consumer-local skills)*\n<!-- /local -->\n## Reviewer model\n<!-- local -->\nDefault reviewer model: (none — reviews inherit the invoking session'"'"'s model)\n<!-- /local -->\n## Checks\n<!-- local -->\n1. **(none yet — no stack exists.)** When it does, the command (`npm test`, `cargo test`) is named here.\n<!-- /local -->\n### Documentation-only paths\n<!-- local -->\n*(reserved: this project'"'"'s own documentation-only paths)*\n<!-- /local -->\n## Project notes\n<!-- local -->\n*(reserved: this consumer'"'"'s own session-start instructions)*\n<!-- /local -->\n' > AGENTS.md
printf '# CONSTITUTION.md\n<!-- local -->\n**Status note:** phase 0.\n<!-- /local -->\n## 3. Protected surfaces\n- `docs/adr/`\n<!-- local -->\n*(reserved: this consumer'"'"'s own protected-path bullets)*\n<!-- /local -->\n## 4. Stack & architecture\n<!-- local -->\n*(reserved: stack and architecture constraints)*\n<!-- /local -->\n' > CONSTITUTION.md
printf 'node_modules\n# <!-- local -->\n# <!-- /local -->\n' > .gitignore
echo old > .claude/skills/t-config/SKILL.md; echo old > .claude/skills/t-work/SKILL.md; echo mine > .claude/skills/l-mine/SKILL.md
echo old > .t-workflow/scripts/protected-paths.sh; echo old > .t-workflow/scripts/check-record.sh; printf 'my-check\n' > .t-workflow/required-checks.local
printf 'name: CI\n    # <!-- local -->\n    timeout-minutes: 20\n    # <!-- /local -->\n# <!-- local -->\n      - run: make lint\n# <!-- /local -->\n# <!-- local -->\n# <!-- /local -->\n' > .github/workflows/ci.yml; printf 'x\n    # <!-- local -->\n    timeout-minutes: 10\n    # <!-- /local -->\n' > .github/workflows/review-gate.yml; echo mine > .github/workflows/deploy.yml
echo old > .github/ISSUE_TEMPLATE/task.yml; echo old > .github/ISSUE_TEMPLATE/initiative.yml; echo old > .github/ISSUE_TEMPLATE/config.yml; echo mine > .github/ISSUE_TEMPLATE/bug.yml
echo v1 > migrations/V1__x.md; echo adr > docs/adr/001-old.md; echo mine > docs/adr/100-mine.md; echo old > docs/workflow.md; echo old > docs/tasks/README.md; echo t > docs/tasks/TEMPLATE.md; echo rec > docs/tasks/000000/12-x.md
echo old > docs/adapters/TRACKER.md; echo old > docs/architecture/manifest.md; echo mine > docs/architecture/mine.md; echo mine > docs/own/notes.md
ln -s AGENTS.md CLAUDE.md; ln -s AGENTS.md GEMINI.md; mkdir -p .agents && ln -s ../.claude/skills .agents/skills; ln -s ../AGENTS.md .github/copilot-instructions.md
git add -A && git commit -qm old
out=$(bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/g" --no-pr 2>&1) || bad "replace (no manifest): $out"
has "$out" 'mode: replace' && has "$out" "the old t-workflow's shape" && ok || bad "replace (no manifest): detected by shape, and says so: $out"
for p in CONSTITUTION.md docs/workflow.md docs/tasks/README.md migrations docs/adr/001-old.md docs/adapters docs/architecture/manifest.md .github/workflows/ci.yml .github/workflows/review-gate.yml .github/ISSUE_TEMPLATE/initiative.yml .github/ISSUE_TEMPLATE/config.yml .claude/skills/t-config .t-workflow/scripts/protected-paths.sh .t-workflow/required-checks.local; do [ -e "$p" ] && bad "replace (no manifest): old file survived: $p"; done; ok
[ -e .github/ISSUE_TEMPLATE/task.yml ] && bad "replace (no manifest): the old task form survived" || ok
for p in .claude/skills/l-mine/SKILL.md .github/workflows/deploy.yml .github/ISSUE_TEMPLATE/bug.yml docs/adr/100-mine.md docs/architecture/mine.md docs/own/notes.md docs/tasks/000000/12-x.md; do [ -e "$p" ] || bad "replace (no manifest): consumer file lost: $p"; done; ok
[ -f .claude/skills/t-work/SKILL.md ] && grep -q '^name: t-work' .claude/skills/t-work/SKILL.md && ok || bad "replace (no manifest): old t-work replaced by the new one"
grep -q '^check=""' .t-workflow/config && grep -q '^reviewer_model=""' .t-workflow/config && ok || bad "replace (no manifest): placeholder slots leave config at defaults: $(grep -vE '^#|^$' .t-workflow/config | tr '\n' ' ')"
head -1 AGENTS.md | grep -q t-workflow && ! grep -q 'reserved' AGENTS.md && ok || bad "replace (no manifest): AGENTS.md rebuilt without placeholders"
grep -q 'my-check' .t-workflow/REPLACED.md && ! grep -q 'make lint' .t-workflow/REPLACED.md && [ -f .github/workflows/build.yml ] && grep -q '^      - run: make lint$' .github/workflows/build.yml && ok || bad "replace (no manifest): required-checks.local reported, the ci slot became build.yml"
grep -q '^    timeout-minutes: 20$' .github/workflows/build.yml && ok || bad "replace (no manifest): the build's timeout comes from ci.yml, not review-gate.yml: $(grep timeout .github/workflows/build.yml)"
[ -f .github/workflows/deploy.yml ] && ok || bad "replace (no manifest): the consumer's own workflow kept"
! grep -q 'timeout-minutes' .t-workflow/REPLACED.md && [ "$(grep -c '^## ' .t-workflow/REPLACED.md)" = 2 ] && ok || bad "replace (no manifest): timeouts and empty slots are not reported (status note and required-checks expected): $(grep '^## ' .t-workflow/REPLACED.md | tr '\n' ';')"
[ -L CLAUDE.md ] && [ -L .github/copilot-instructions.md ] && [ -L .agents/skills ] && ok || bad "replace (no manifest): aliases kept"
grep -q '^node_modules$' .gitignore && ! grep -q 'local -->' .gitignore && ok || bad "replace (no manifest): gitignore kept, markers stripped"
(cd "$tmp/g" && git add -A && git commit -qm installed-v3) >/dev/null 2>&1
out=$(bash "$ROOT/install.sh" v4 --from "$ROOT" --dir "$tmp/g" --no-pr 2>&1); has "$out" 'mode: update' && ok || bad "after replace, the next run is an update: $out"
mkdir -p "$tmp/k/.t-workflow/scripts" "$tmp/k/.github/workflows" && cd "$tmp/k" && git init -q -b main && echo c > CONSTITUTION.md && echo o > .t-workflow/scripts/protected-paths.sh && printf 'name: CI\n# <!-- local -->\n      - run: make lint\n# <!-- /local -->\n' > .github/workflows/ci.yml && echo 'name: mine' > .github/workflows/build.yml && git add -A && git commit -qm old
bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/k" --no-pr >/dev/null 2>&1 || bad "replace (existing build.yml)"
[ "$(cat .github/workflows/build.yml)" = "name: mine" ] && grep -q 'make lint' .t-workflow/REPLACED.md && ok || bad "replace: an existing build.yml is kept and the slot's steps are reported instead: $(cat .t-workflow/REPLACED.md 2>/dev/null | tail -5)"
mkdir -p "$tmp/h/.t-workflow/scripts" && cd "$tmp/h" && git init -q -b main && printf '# C\n## 3. Protected surfaces\n<!-- local -->\n*(reserved: bullets)*\n<!-- /local -->\n' > CONSTITUTION.md && echo old > .t-workflow/scripts/protected-paths.sh && printf '# A\n## Project notes\n<!-- local -->\n*(reserved: notes)*\n<!-- /local -->\n' > AGENTS.md && git add -A && git commit -qm old
bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/h" --no-pr >/dev/null 2>&1 || bad "replace (placeholders only)"
[ ! -e "$tmp/h/.t-workflow/REPLACED.md" ] && ok || bad "replace: no REPLACED.md when every slot was a placeholder"

echo "# config parsing (never executed)"
mkdir -p "$tmp/cfg/.t-workflow"
printf '%s\n' '# a comment' 'check="tests/test.sh"' 'protected="db/migrate/*"' \
  'check="x"; touch "$tmp/cfg-PWNED"' 'exempt="a" # trailing junk' 'bogus="y"' \
  'reviewer_model="m"; touch "$tmp/cfg-PWNED2"' > "$tmp/cfg/.t-workflow/config"
# shellcheck disable=SC2154 # check, protected, exempt, docs, reviewer_model: set by lib.sh, sourced dynamically above
cfgvals=$(cd "$tmp/cfg" && . "$S/lib.sh" 2>/dev/null && printf 'check=%s protected=%s exempt=%s docs=%s reviewer=%s' "$check" "$protected" "$exempt" "$docs" "$reviewer_model")
[ "$cfgvals" = "check=tests/test.sh protected=db/migrate/* exempt= docs= reviewer=" ] && ok || bad "config: plain key=value lines parse, the rest is ignored: $cfgvals"
[ ! -e "$tmp/cfg-PWNED" ] && [ ! -e "$tmp/cfg-PWNED2" ] && ok || bad "config: a shell payload in the config never runs"
# an assignment the parser does not accept is said on stderr, once per line, with the documented empty value
printf '%s\n' '# a comment' "check='tests/test.sh'" '' 'docs="$HOME/site"' 'protected="ok/*"' > "$tmp/cfg/.t-workflow/config"
cfgerr=$(cd "$tmp/cfg" && { . "$S/lib.sh" && printf 'check=[%s] docs=[%s] protected=[%s]\n' "$check" "$docs" "$protected"; } 2>&1)
has "$cfgerr" "^config: line 2 ignored: check='tests/test.sh'$" && has "$cfgerr" '^config: line 4 ignored: docs="\$HOME/site"$' && has "$cfgerr" '^check=\[\] docs=\[\] protected=\[ok/\*\]$' && [ "$(printf '%s\n' "$cfgerr" | grep -c ignored)" = 2 ] && ok || bad "config: an ignored assignment is reported once, comments and blanks are not: $cfgerr"
cfgerr=$(cd "$tmp/b" && . "$S/lib.sh" 2>&1); [ -z "$cfgerr" ] && ok || bad "config: the installed default config reports nothing: $cfgerr"
printf 'protected="zz-only/*"\n' > "$tmp/cfg-base"
expect_exit 0 "config: TW_CONFIG_FILE redirects the read (the CI merged copy)" env TW_CONFIG_FILE="$tmp/cfg-base" "$S/protected.sh" zz-only/a.txt
expect_exit 1 "config: without it the working tree's own values apply" bash -c "cd $tmp/cfg && $S/protected.sh zz-only/a.txt"

echo "# ci.sh (offline parts)"
mkdir -p "$tmp/e" && (cd "$tmp/e" && git init -q -b main && echo base > base.txt && git add -A && git commit -qm init && git clone -q --bare . "$tmp/e-origin" && git remote add origin "$tmp/e-origin" && git fetch -q origin)
bash "$ROOT/install.sh" v0 --from "$ROOT" --dir "$tmp/e" --no-pr >/dev/null 2>&1 || bad "ci fixture: install"
cd "$tmp/e" && git add -A && git commit -qm adopt
mkdir -p "$tmp/bin"; printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/gh"; chmod +x "$tmp/bin/gh"
ci() { BASE_REF=main HEAD_REF="$1" PR_NUMBER=1 PR_TITLE="$2" GH_TOKEN=x PATH="$tmp/bin:$PATH" "$S/ci.sh" 2>&1; }
# base (origin/main) has no t-workflow yet: adoption PR
out=$(ci wip/5-thing "[5] Thing"); has "$out" 'adoption PR' && ok || bad "ci: base without t-workflow is an adoption PR: $out"
has "$out" "is not run here" && ok || bad "ci: says the build is not run here"
# now the base carries t-workflow: the gates are in force
git push -q origin main; git fetch -q origin
git checkout -q -b wip/5-thing
sed 's/7/5/g; s/Fixture/Thing/; s/<the goal, from the issue>/Do it./; s/^## Ask$/## Asked/' "$tmp/a/docs/tasks/7-fixture.md" > docs/tasks/5-thing.md
echo x > file.txt; git add -A; git commit -qm work
out=$(ci wip/5-thing "Thing")
has "$out" 'OK: record docs/tasks/5-thing.md' && ok || bad "ci: record ok: $out"
has "$out" "FAIL: PR title must start with '\\[5\\] '" && ok || bad "ci: title fail: $out"
has "$out" 'FAIL: cannot read issue #5' && ok || bad "ci: tracker unreachable is a failure, not a pass"
out=$(ci feature/x x); has "$out" 'is not wip/<id>-<slug>' && ok || bad "ci: non-task branch fails"
# policy comes from the base branch: the PR cannot exempt itself with its own config
sedi 's|^exempt=""|exempt="dependabot/* feature/*"|' .t-workflow/config
out=$(ci feature/x x); ! has "$out" 'exempt from the task gates' && has "$out" 'is not wip/<id>-<slug>' && ok || bad "ci: a PR cannot exempt itself with its own config: $out"
git add -A && git commit -qm "self-exempt attempt"
out=$(ci feature/x x); ! has "$out" 'exempt from the task gates' && ok || bad "ci: a committed self-exempt is still judged by the base: $out"
has "$out" 'policy: exempt/protected/docs from origin/main' && ok || bad "ci: says where the policy came from: $out"
# ... but the base can: exempt the branch there and the gate stands down
git checkout -q main && sedi 's|^exempt=""|exempt="dependabot/* feature/*"|' .t-workflow/config && git add -A && git commit -qm "exempt feature branches" && git push -q origin main && git fetch -q origin && git checkout -q wip/5-thing
out=$(ci feature/x x); has "$out" 'exempt from the task gates' && ok || bad "ci: exempt branch (policy from the base)"
# PR_REF: the checkout can stay on main throughout; the PR is only ever read through
# the ref (this is what the workflow does — checkout stays on the base branch, PR_REF
# points at a fetched commit — instead of checking the PR out and running from it)
git checkout -q main
out=$(PR_REF=wip/5-thing ci wip/5-thing "[5] Thing")
has "$out" 'OK: record docs/tasks/5-thing.md' && ok || bad "ci: PR_REF reads the record through the ref: $out"
has "$out" 'OK: title starts with \[5\]' && ok || bad "ci: PR_REF still checks the PR's title: $out"
[ ! -e docs/tasks/5-thing.md ] && ok || bad "ci: PR_REF never checks the PR's files out onto disk"
git checkout -q wip/5-thing
sedi 's|^check=""|check="false"|' .t-workflow/config
if out=$(ci feature/x x); then ! has "$out" 'check 1 passed' && ! has "$out" 'running check' && ok || bad "ci: the check command is never run in CI: $out"; else bad "ci: a failing check command must not fail CI (the project's own CI runs it): $out"; fi

echo "# t-workflow.yml: the triggers, and the gate step in three base shapes"
wf="$ROOT/.github/workflows/t-workflow.yml"
# pull_request_target judges (GitHub reads it from the base); pull_request exists only
# for PRs that touch this file, whose base copy is missing or has the wrong trigger.
grep -qE '^  pull_request_target:' "$wf" && ok || bad "workflow: must trigger on pull_request_target, so GitHub reads it from the base branch"
awk '/^  pull_request:/{f=1; next} f && /^  [a-z]/{exit} f' "$wf" | grep -qE "^    paths: \['\.github/workflows/t-workflow\.yml'\]" && ok || bad "workflow: pull_request must be filtered to PRs that touch the workflow file, and nothing else"
awk '/^  pull_request_target:/{f=1; next} f && /^  [a-z]/{exit} f' "$wf" | grep -q 'paths' && bad "workflow: pull_request_target must not be path-filtered" || ok
grep -qE '^  group: t-workflow-\$\{\{ github\.event_name \}\}-' "$wf" && ok || bad "workflow: the concurrency group must include the event, or the two runs on a PR touching this file cancel each other"
# The step itself, extracted from the YAML so the test cannot drift from what runs.
step=$(awk '/^        run: \|$/{f=1; next} f && /^          /{sub(/^          /, ""); print; next} f{exit}' "$wf")
has "$step" 'git archive "\$scripts_ref" .t-workflow/scripts' && ok || bad "workflow: could not extract the run step from the YAML"
# gate_run <origin> <checkout-ref> <base-ref> <pr-ref>: the step as CI runs it — a
# fresh checkout at <checkout-ref>, refs/pull/1/head pointing at the PR, one env.
gate_run() {
  git -C "$1" update-ref refs/pull/1/head "$(git -C "$1" rev-parse "$4")"
  rm -rf "$tmp/runner"; git clone -q "$1" "$tmp/runner" && cd "$tmp/runner" || return 9
  git fetch -q origin '+refs/pull/*:refs/pull/*' && git checkout -q --detach "$2" || return 9
  (export BASE_REF="$3" HEAD_REF=wip/1-x PR_NUMBER=1 PR_TITLE="[1] x" GH_TOKEN=x PR_REF=refs/heads/_pr_head PATH="$tmp/bin:$PATH"; bash -c "$step" 2>&1)
}
# origin_shape <dir>: a bare origin whose main is <dir>'s main; PR branch wip/1-x.
mk_origin() { git clone -q --bare "$1" "$1.git"; echo "$1.git"; }
stub_ci() { # <dir> <marker> <exit>: a .t-workflow/scripts/ci.sh that says which copy ran
  mkdir -p "$1/.t-workflow/scripts"
  printf '#!/usr/bin/env bash\necho "ran: %s"\necho "checkout: $(git rev-parse HEAD)"\ngit diff --name-only "origin/$BASE_REF...${PR_REF:-HEAD}"\nexit %s\n' "$2" "$3" > "$1/.t-workflow/scripts/ci.sh"
  chmod +x "$1/.t-workflow/scripts/ci.sh"
}
# 1. Adoption: the base has no .t-workflow at all; the PR brings the real scripts, so
#    they run and ci.sh's adoption exemption passes. Checkout is the merge commit, as
#    under pull_request.
mkdir -p "$tmp/w1" && (cd "$tmp/w1" && git init -q -b main && echo base > base.txt && git add -A && git commit -qm init) || bad "w1 init"
o1=$(mk_origin "$tmp/w1"); git -C "$tmp/w1" remote add origin "$o1"; git -C "$tmp/w1" fetch -q origin
(cd "$tmp/w1" && git checkout -q -b wip/1-x && bash "$ROOT/install.sh" v0 --from "$ROOT" --dir . --no-pr >/dev/null 2>&1 && git add -A && git commit -qm adopt && git push -q origin wip/1-x && git checkout -q main && git merge -q --no-ff -m merge wip/1-x && git push -q origin HEAD:refs/pull/1/merge && git reset -q --hard origin/main) || bad "w1: build the adoption PR"
out=$(gate_run "$o1" refs/pull/1/merge main wip/1-x); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'adoption PR: main has no t-workflow yet' && ok || bad "step, adoption: the PR's scripts run and the exemption passes (exit $rc): $out"
# 2. Update from before the trigger: the base carries scripts and the old workflow
#    (pull_request); the PR changes the workflow and its own ci.sh, which must not run.
#    Checkout is the merge commit, as under pull_request.
mkdir -p "$tmp/w2" && (cd "$tmp/w2" && git init -q -b main && mkdir -p .t-workflow .github/workflows && echo rules > .t-workflow/AGENTS.md && printf 'on:\n  pull_request:\n' > .github/workflows/t-workflow.yml) || bad "w2 init"
stub_ci "$tmp/w2" "the base's copy (before the trigger change)" 0
(cd "$tmp/w2" && git add -A && git commit -qm base) || bad "w2 base"
o2=$(mk_origin "$tmp/w2"); git -C "$tmp/w2" remote add origin "$o2"; git -C "$tmp/w2" fetch -q origin
(cd "$tmp/w2" && git checkout -q -b wip/1-x && cp "$wf" .github/workflows/t-workflow.yml && stub_ci . "the PR's copy" 1 && git add -A && git commit -qm update && git push -q origin wip/1-x && git checkout -q main && git merge -q --no-ff -m merge wip/1-x && git push -q origin HEAD:refs/pull/1/merge && git reset -q --hard origin/main) || bad "w2: build the update PR"
out=$(gate_run "$o2" refs/pull/1/merge main wip/1-x); rc=$?
[ "$rc" -eq 0 ] && has "$out" "ran: the base's copy" && ! has "$out" "ran: the PR's copy" && ok || bad "step, update: the base's scripts judge the PR, never the PR's (exit $rc): $out"
has "$out" '.github/workflows/t-workflow.yml' && ok || bad "step, update: the base's scripts see the PR's diff through PR_REF: $out"
has "$out" "checkout: $(git -C "$o2" rev-parse refs/pull/1/merge)" && ok || bad "step, update: the checkout is the merge commit, as under pull_request, and the step does not care: $out"
# 3. Steady state: the base carries the new workflow; a PR edits it and ci.sh. The
#    base's copy runs, from a checkout on the base, as under pull_request_target.
mkdir -p "$tmp/w3" && (cd "$tmp/w3" && git init -q -b main && mkdir -p .t-workflow .github/workflows && echo rules > .t-workflow/AGENTS.md && cp "$wf" .github/workflows/t-workflow.yml) || bad "w3 init"
stub_ci "$tmp/w3" "the base's copy" 0
(cd "$tmp/w3" && git add -A && git commit -qm base) || bad "w3 base"
o3=$(mk_origin "$tmp/w3"); git -C "$tmp/w3" remote add origin "$o3"; git -C "$tmp/w3" fetch -q origin
(cd "$tmp/w3" && git checkout -q -b wip/1-x && echo "# edited" >> .github/workflows/t-workflow.yml && stub_ci . "the PR's copy" 1 && git add -A && git commit -qm edit && git push -q origin wip/1-x && git checkout -q main) || bad "w3: build the PR"
out=$(gate_run "$o3" main main wip/1-x); rc=$?
[ "$rc" -eq 0 ] && has "$out" "ran: the base's copy" && ! has "$out" "ran: the PR's copy" && ok || bad "step, steady state: the base's scripts judge a PR that rewrites them (exit $rc): $out"
has "$out" "checkout: $(git -C "$o3" rev-parse main)" && ok || bad "step, steady state: the checkout is the base, as under pull_request_target: $out"
# A PR that deletes the workflow file has no pull_request run (no file in its tree) and
# is still judged by the base's pull_request_target run: nothing in the step to test.

echo "# rerun-ci.sh (stubbed gh)"
mkdir -p "$tmp/gh2"; cat > "$tmp/gh2/gh" <<'STUB'
#!/usr/bin/env bash
# stub gh: $PRVIEW is `pr view`'s JSON (empty = fail), $RUNS is `run list`'s JSON (empty = fail),
# every `run rerun` id is appended to $RERUNS. The exact flag shapes the script relies on are checked.
case "$1 $2" in
  "pr view") [ -n "${PRVIEW:-}" ] || exit 1; [[ "$*" == *"--json headRefOid,isDraft"* ]] || { echo "stub: unexpected pr view flags: $*" >&2; exit 9; }; printf '%s' "$PRVIEW" ;;
  "run list") [ -n "${RUNS:-}" ] || exit 1; [[ "$*" == *"--workflow t-workflow"* && "$*" == *"--commit abc123"* && "$*" == *"--json databaseId,status,conclusion"* ]] || { echo "stub: unexpected run list flags: $*" >&2; exit 9; }; printf '%s' "$RUNS" ;;
  "run rerun") echo "$3" >> "$RERUNS"; [ "${RERUN_FAILS:-}" = 1 ] && exit 1; exit 0 ;;
  *) echo "stub: unexpected gh $*" >&2; exit 9 ;;
esac
STUB
chmod +x "$tmp/gh2/gh"; export RERUNS="$tmp/reruns"; : > "$RERUNS"
cd "$tmp/b" || exit; export PRVIEW='{"headRefOid":"abc123","isDraft":false}'
rr() { PATH="$tmp/gh2:$PATH" "$S/rerun-ci.sh" 7 2>&1; }
out=$(PRVIEW='{"headRefOid":"abc123","isDraft":true}' rr); has "$out" 'is a draft' && [ ! -s "$RERUNS" ] && ok || bad "rerun-ci: draft PR needs no re-run: $out"
out=$(RUNS='[]' rr); has "$out" 'no t-workflow run at abc123' && [ ! -s "$RERUNS" ] && ok || bad "rerun-ci: no run: $out"
out=$(RUNS='[{"databaseId":9,"status":"in_progress","conclusion":null}]' rr); has "$out" 'still in_progress; if it ends red, run this again' && [ ! -s "$RERUNS" ] && ok || bad "rerun-ci: in progress: $out"
out=$(RUNS='[{"databaseId":9,"status":"completed","conclusion":"success"}]' rr); has "$out" 'already green' && [ ! -s "$RERUNS" ] && ok || bad "rerun-ci: green is a no-op: $out"
out=$(RUNS='[{"databaseId":9,"status":"completed","conclusion":"skipped"}]' rr); has "$out" 'was skipped.*nothing to re-run' && [ ! -s "$RERUNS" ] && ok || bad "rerun-ci: skipped run is not re-run: $out"
out=$(RUNS='[{"databaseId":9,"status":"completed","conclusion":"failure"},{"databaseId":8,"status":"completed","conclusion":"success"}]' rr)
has "$out" 're-running t-workflow run 9 at abc123 (was failure)' && [ "$(cat "$RERUNS")" = 9 ] && ok || bad "rerun-ci: re-runs the newest red run: $out / $(cat "$RERUNS")"
: > "$RERUNS"
# A PR that touches the workflow file has two runs at one commit (both events); both red
# until the review exists, and one left red still blocks, so every red one is re-run.
out=$(RUNS='[{"databaseId":9,"status":"completed","conclusion":"failure"},{"databaseId":8,"status":"completed","conclusion":"failure"},{"databaseId":7,"status":"completed","conclusion":"success"}]' rr)
[ "$(sort "$RERUNS" | tr '\n' ' ')" = "8 9 " ] && has "$out" 're-running t-workflow run 8' && has "$out" 'run 7 at abc123 is already green' && ok || bad "rerun-ci: re-runs every red run at the head: $out / $(cat "$RERUNS")"
: > "$RERUNS"
out=$(RUNS='[{"databaseId":9,"status":"completed","conclusion":"failure"}]' RERUN_FAILS=1 rr); rc=$?
[ "$rc" -eq 1 ] && has "$out" 'could not re-run' && ok || bad "rerun-ci: reports a failed re-run (exit $rc): $out"
out=$(RUNS='' rr); rc=$?; [ "$rc" -eq 2 ] && has "$out" 'cannot list runs' && ok || bad "rerun-ci: a failed run list is an error, not 'no run' (exit $rc): $out"
out=$(PRVIEW='' rr); rc=$?; [ "$rc" -eq 2 ] && has "$out" 'cannot read PR' && ok || bad "rerun-ci: unreadable PR (exit $rc): $out"
# a flag-shaped argument gets gh's help text and exit 0: no head, and an empty --commit would list the whole repository's runs
: > "$RERUNS"
out=$(PRVIEW='{"isDraft":false}' RUNS='[{"databaseId":9,"status":"completed","conclusion":"failure"}]' rr); rc=$?
[ "$rc" -eq 2 ] && has "$out" 'no head commit' && [ ! -s "$RERUNS" ] && ok || bad "rerun-ci: an empty head is an error and re-runs nothing (exit $rc): $out"
grep -q 'pull_request_review' "$ROOT/.github/workflows/t-workflow.yml" && bad "workflow: still triggers on reviews" || ok

echo "# issue.sh children / parent / blocking (stubbed gh, GitHub's real shape)"
mkdir -p "$tmp/gh3"
cat > "$tmp/gh3/gh" <<'STUB'
#!/usr/bin/env bash
# stub gh: returns GitHub's real JSON for the fields, then applies the --jq expression the script passed
args=("$@"); expr=""; for i in "${!args[@]}"; do [ "${args[$i]}" = "--jq" ] && expr="${args[$((i+1))]}"; done
case "$*" in
  "repo view"*) echo "o/r"; exit 0 ;;
  *"subIssues(first:100)"*) json='{"data":{"repository":{"issue":{"subIssues":{"nodes":[{"number":8,"state":"OPEN","stateReason":null,"title":"Step 1"},{"number":9,"state":"CLOSED","stateReason":"COMPLETED","title":"Step 2"}]}}}}}' ;;
  *"--json parent"*)  json='{"parent":{"id":"I_0","number":7,"state":"OPEN","title":"Init","url":"u"}}'; [ "$3" = 33 ] && json='{"parent":null}' ;;
  *"--json blocking"*)  json='{"blocking":{"nodes":[{"id":"I_3","number":21,"state":"OPEN","title":"Step 14","url":"u"}]}}' ;;
  *) echo "stub: unexpected gh $*" >&2; exit 9 ;;
esac
if [ -n "$expr" ]; then printf '%s' "$json" | jq -rc "$expr"; else printf '%s' "$json"; fi
STUB
chmod +x "$tmp/gh3/gh"
out=$(PATH="$tmp/gh3:$PATH" "$S/issue.sh" children 7 2>&1); [ "$out" = '[{"number":8,"title":"Step 1","state":"OPEN","stateReason":null},{"number":9,"title":"Step 2","state":"CLOSED","stateReason":"COMPLETED"}]' ] && ok || bad "issue.sh children carries stateReason: $out"
out=$(PATH="$tmp/gh3:$PATH" "$S/issue.sh" parent 8 2>&1); [ "$out" = 7 ] && ok || bad "issue.sh parent: $out"
expect_exit 1 "issue.sh parent: none" env PATH="$tmp/gh3:$PATH" "$S/issue.sh" parent 33
out=$(PATH="$tmp/gh3:$PATH" "$S/issue.sh" blocking 9 2>&1); [ "$out" = '[{"number":21,"title":"Step 14","state":"OPEN"}]' ] && ok || bad "issue.sh blocking: $out"

echo "# protect.sh (stubbed gh)"
mkdir -p "$tmp/gh4"; cat > "$tmp/gh4/gh" <<'STUB'
#!/usr/bin/env bash
# stub gh. PROTECTION: the protection JSON, or 404 / 403 / 500 / neterr to fail the read that way.
# PATCH_FAILS=1 makes the required-checks PATCH fail as GitHub does when the rule is not enabled.
# Every write is appended to $CALLS as "<method> <path> <body>".
case "$1 $2" in
  "repo view") echo "o/r" ;;
  "api repos/o/r/branches/main/protection")
    case "${PROTECTION:-404}" in
      404) echo "HTTP 404: Branch not protected (https://api.github.com/...)" >&2; exit 1 ;;
      403) echo "HTTP 403: Upgrade to GitHub Pro or make this repository public" >&2; exit 1 ;;
      500) echo "HTTP 500: Internal Server Error" >&2; exit 1 ;;
      neterr) echo "error connecting to api.github.com" >&2; exit 1 ;;
      *) printf '%s' "$PROTECTION" ;;
    esac ;;
  "api -X")
    body=""; [[ "$*" == *"--input -"* ]] && body=$(cat)
    if [ "$3" = PATCH ] && [[ "$4" == *"/required_status_checks" ]] && [ "${PATCH_FAILS:-}" = 1 ]; then
      echo "HTTP 404: Required status checks not enabled" >&2; exit 1
    fi
    echo "$3 $4 $body" >> "$CALLS" ;;
  "api graphql")
    # RULES: the existing branchProtectionRules nodes; RULES_FAIL=1 fails the read;
    # CREATE_FAILS=upgrade refuses the create the way a free private repository does.
    # Writes land in $CALLS as "GRAPHQL create <-F values>" or "GRAPHQL update <variables JSON>".
    vars=""; args=("$@"); for i in "${!args[@]}"; do [ "${args[$i]}" = "-F" ] && vars="$vars ${args[$((i+1))]}"; done
    q="$*"; [[ "$*" == *"--input -"* ]] && { body=$(cat); q=$(printf '%s' "$body" | jq -r .query); vars=" $(printf '%s' "$body" | jq -c .variables)"; }
    case "$q" in
      *branchProtectionRules*) [ "${RULES_FAIL:-}" = 1 ] && { echo "error connecting to api.github.com" >&2; exit 1; }
        printf '{"data":{"repository":{"id":"R_1","branchProtectionRules":{"nodes":%s}}}}' "${RULES:-[]}" ;;
      *createBranchProtectionRule*) [ "${CREATE_FAILS:-}" = upgrade ] && { echo "GraphQL: Upgrade to GitHub Pro or make this repository public to enable this feature. (createBranchProtectionRule)" >&2; exit 1; }
        echo "GRAPHQL create$vars" >> "$CALLS"; echo '{"data":{}}' ;;
      *updateBranchProtectionRule*) echo "GRAPHQL update$vars" >> "$CALLS"; echo '{"data":{}}' ;;
      *) echo "stub: unexpected graphql $*" >&2; exit 9 ;;
    esac ;;
  *) echo "stub: unexpected gh $*" >&2; exit 9 ;;
esac
STUB
chmod +x "$tmp/gh4/gh"; export CALLS="$tmp/calls"
cd "$tmp/b" || exit
pt() { PATH="$tmp/gh4:$PATH" "$S/protect.sh" "$@" 2>&1; }
writes() { grep 'protection' "$CALLS" || true; }   # writes to the protection endpoints only (merge settings excluded)
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":{"strict":false,"contexts":["checks","cold-review","sonar"]},"enforce_admins":{"enabled":true},"required_pull_request_reviews":{"required_approving_review_count":1}}' pt --remove checks --remove cold-review --add build)
has "$out" 'required checks before: checks cold-review sonar' && has "$out" 'required checks now: sonar t-workflow build' && ok || bad "protect: merges into the existing list: $out"
[ "$(writes)" = 'PATCH repos/o/r/branches/main/protection/required_status_checks {"strict":false,"contexts":["sonar","t-workflow","build"]}' ] && ok || bad "protect: only the required-checks endpoint is written, everything else untouched: $(writes)"
: > "$CALLS"; out=$(PROTECTION=404 pt); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'protected — PRs only' && has "$(writes)" '^PUT repos/o/r/branches/main/protection {"required_status_checks":{"strict":false,"contexts":\["t-workflow"\]}' && ok || bad "protect: a confirmed 404 → the minimal set (exit $rc): $out / $(writes)"
: > "$CALLS"; out=$(PROTECTION=403 pt); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'not available on this repository' && [ -z "$(writes)" ] && ok || bad "protect: a plan refusal is reported, nothing written (exit $rc): $out"
: > "$CALLS"; out=$(PROTECTION=500 pt); rc=$?
[ "$rc" -eq 2 ] && has "$out" 'could not read the branch protection (HTTP 500); nothing was changed' && [ -z "$(writes)" ] && ok || bad "protect: a server error never replaces protection (exit $rc): $out / $(writes)"
: > "$CALLS"; out=$(PROTECTION=neterr pt); rc=$?
[ "$rc" -eq 2 ] && has "$out" 'HTTP unknown' && [ -z "$(writes)" ] && ok || bad "protect: a network error never replaces protection (exit $rc): $out / $(writes)"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":null,"enforce_admins":{"enabled":true},"required_pull_request_reviews":{"dismiss_stale_reviews":true,"require_code_owner_reviews":false,"required_approving_review_count":1,"require_last_push_approval":false},"restrictions":null,"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},"required_linear_history":{"enabled":true}}' PATCH_FAILS=1 pt --add build); rc=$?
w=$(writes); [ "$rc" -eq 0 ] && has "$out" 'required checks enabled: t-workflow build' && has "$w" '^PUT ' && has "$w" '"enforce_admins":true' && has "$w" '"required_approving_review_count":1' && has "$w" '"dismiss_stale_reviews":true' && has "$w" '"required_linear_history":true' && has "$w" '"contexts":\["t-workflow","build"\]' && ok || bad "protect: a reviews-only rule gets required checks enabled with every rule carried (exit $rc): $out / $w"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":null,"enforce_admins":{"enabled":false},"required_pull_request_reviews":{"dismissal_restrictions":{"users":[{"login":"alice"}],"teams":[{"slug":"core"}],"apps":[]},"bypass_pull_request_allowances":{"users":[],"teams":[],"apps":[{"slug":"release-bot"}]},"required_approving_review_count":2},"restrictions":{"users":[{"login":"bob"}],"teams":[],"apps":[]},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false},"block_creations":{"enabled":true},"lock_branch":{"enabled":true},"allow_fork_syncing":{"enabled":true},"required_conversation_resolution":{"enabled":true}}' PATCH_FAILS=1 pt); rc=$?
w=$(writes); [ "$rc" -eq 0 ] && has "$w" '"dismissal_restrictions":{"users":\["alice"\],"teams":\["core"\],"apps":\[\]}' && has "$w" '"bypass_pull_request_allowances":{"users":\[\],"teams":\[\],"apps":\["release-bot"\]}' && has "$w" '"restrictions":{"users":\["bob"\],"teams":\[\],"apps":\[\]}' && has "$w" '"block_creations":true' && has "$w" '"lock_branch":true' && has "$w" '"allow_fork_syncing":true' && has "$w" '"required_conversation_resolution":true' && ok || bad "protect: the optional rules survive the re-send (exit $rc): $w"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":null,"required_pull_request_reviews":{"dismissal_restrictions":{"users":[],"teams":[],"apps":[]},"required_approving_review_count":1}}' PATCH_FAILS=1 pt); rc=$?
has "$(writes)" '"dismissal_restrictions":{"users":\[\],"teams":\[\],"apps":\[\]}' && ok || bad "protect: an empty dismissal restriction (the setting on, nobody listed) is carried, not dropped: $(writes)"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":null,"required_pull_request_reviews":{"required_approving_review_count":1}}' PATCH_FAILS=1 pt); rc=$?
printf '%s' "$(writes)" | grep -q 'dismissal_restrictions' && bad "protect: no dismissal key on the GET means none is sent: $(writes)" || ok
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":{"strict":true,"contexts":["t-workflow"]}}' pt --add build)
has "$(writes)" '{"strict":true,"contexts":\["t-workflow","build"\]}' && ok || bad "protect: keeps strict and never duplicates t-workflow: $(writes)"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":{"strict":false,"contexts":["cax","c.x"]}}' pt --remove c.x)
has "$(writes)" '"contexts":\["cax","t-workflow"\]' && ok || bad "protect: a removed context is matched literally, not as a pattern: $(writes)"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":{"strict":false,"contexts":["a"]}}' pt); rc=$?
[ "$rc" -eq 0 ] && has "$(writes)" '"contexts":\["a","t-workflow"\]' && ok || bad "protect: no --add/--remove at all works (empty arrays, bash 3.2 idiom) (exit $rc): $out"

echo "# protect.sh: the wip/*-integration pattern rule (GraphQL)"
gql() { grep '^GRAPHQL' "$CALLS" || true; }
: > "$CALLS"; out=$(PROTECTION=404 pt); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'wip/\*-integration protected' && has "$(gql)" '^GRAPHQL create r=R_1 p=wip/\*-integration$' && ok || bad "protect: no rule for the pattern → created after the trunk's (exit $rc): $out / $(gql)"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":{"strict":false,"contexts":["a"]}}' RULES='[{"id":"BPR_main","pattern":"main","requiredStatusCheckContexts":["a"]},{"id":"BPR_int","pattern":"wip/*-integration","requiredStatusCheckContexts":["build","checks"]}]' pt --remove checks --add sonar); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'wip/\*-integration required checks now: build t-workflow sonar' && has "$(gql)" '^GRAPHQL update {"id":"BPR_int","ctx":\["build","t-workflow","sonar"\]}$' && ! has "$(gql)" 'create' && ok || bad "protect: an existing pattern rule is merged into, not replaced, the contexts sent as a JSON list (exit $rc): $out / $(gql)"
: > "$CALLS"; out=$(PROTECTION='{"required_status_checks":{"strict":false,"contexts":["t-workflow"]}}' RULES='[{"id":"BPR_int","pattern":"wip/*-integration","requiredStatusCheckContexts":["t-workflow"]}]' pt --remove t-workflow); rc=$?
[ "$rc" -eq 0 ] && has "$(gql)" '^GRAPHQL update {"id":"BPR_int","ctx":\[\]}$' && ok || bad "protect: an empty contexts list is sent as an empty list, the variable present (exit $rc): $out / $(gql)"
: > "$CALLS"; out=$(PROTECTION=404 CREATE_FAILS=upgrade pt); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'not available on this repository' && has "$out" 'wip/\*-integration rule holds by convention' && [ -z "$(gql)" ] && ok || bad "protect: a plan refusal on the pattern rule is reported, exit 0 (exit $rc): $out"
: > "$CALLS"; out=$(PROTECTION=404 RULES_FAIL=1 pt); rc=$?
[ "$rc" -eq 2 ] && has "$out" 'could not read the branch protection rules; nothing was changed' && [ -z "$(gql)" ] && ok || bad "protect: an unreadable rule list never writes the pattern rule (exit $rc): $out"
: > "$CALLS"; out=$(PROTECTION=403 pt); [ -z "$(gql)" ] && ok || bad "protect: no plan for the trunk's rule → the pattern rule is not attempted either: $(gql)"

echo "# gate.sh work / ship: a task, an initiative's child, the initiative (stubbed gh, bare origin)"
mkdir -p "$tmp/gh5"; cat > "$tmp/gh5/gh" <<'STUB'
#!/usr/bin/env bash
# stub gh for the gates. Fixtures in the environment, in gh's own JSON shapes:
#   ISSUES   {"<n>": issue view object}          BLOCKERS {"<n>": blockedBy nodes}
#   PRS      [pr view objects, with "state"]      CHILDREN {"<n>": subIssues nodes}
# --jq/-q expressions are applied as gh applies them.
args=("$@"); expr=""; st=open; num=""
for i in "${!args[@]}"; do case "${args[$i]}" in --jq|-q) expr="${args[$((i+1))]}" ;; --state) st="${args[$((i+1))]}" ;; -F) case "${args[$((i+1))]}" in num=*) num="${args[$((i+1))]#num=}" ;; esac ;; esac; done
emit() { if [ -n "$expr" ]; then printf '%s' "$1" | jq -rc "$expr"; else printf '%s' "$1"; fi; }
case "$1 $2" in
  "repo view") echo "o/r" ;;
  "issue view") j=$(printf '%s' "$ISSUES" | jq -c --arg n "$3" '.[$n] // empty'); [ -n "$j" ] || exit 1; emit "$j" ;;
  "issue list") emit "$(printf '%s' "$ISSUES" | jq -c --argjson b "${BLOCKERS:-{\}}" --arg s "$st" '[to_entries[] | .value + {blockedBy: {nodes: ($b[.key] // [])}} | select($s == "all" or (.state | ascii_downcase) == $s)]')" ;;
  "pr diff") echo "diff --git a/x b/x" ;;
  "pr list") emit "$(printf '%s' "${PRS:-[]}" | jq -c --arg s "$st" '[.[] | select($s == "all" or (.state | ascii_downcase) == $s)]')" ;;
  "pr view") j=$(printf '%s' "${PRS:-[]}" | jq -c --argjson n "$3" '.[] | select(.number == $n)'); [ -n "$j" ] || exit 1; emit "$j" ;;
  "api graphql")
    case "$*" in
      *blockedBy*) emit "$(printf '%s' "${BLOCKERS:-{\}}" | jq -c --arg n "$num" '{data:{repository:{issue:{blockedBy:{nodes:(.[$n] // [])}}}}}')" ;;
      *subIssues*) emit "$(printf '%s' "${CHILDREN:-{\}}" | jq -c --arg n "$num" '{data:{repository:{issue:{subIssues:{nodes:(.[$n] // [])}}}}}')" ;;
      *) echo "stub: unexpected graphql $*" >&2; exit 9 ;;
    esac ;;
  *) echo "stub: unexpected gh $*" >&2; exit 9 ;;
esac
STUB
chmod +x "$tmp/gh5/gh"
mkdir -p "$tmp/i" && (cd "$tmp/i" && git init -q -b main && echo base > base.txt && git add -A && git commit -qm init && git clone -q --bare . "$tmp/i-origin" && git remote add origin "$tmp/i-origin" && git fetch -q origin)
bash "$ROOT/install.sh" v0 --from "$ROOT" --dir "$tmp/i" --no-pr >/dev/null 2>&1 || bad "gate fixture: install"
cd "$tmp/i" && git add -A && git commit -qm adopt && git push -q origin main && git fetch -q origin
export ISSUES='{
  "30": {"number":30,"title":"Init","state":"OPEN","labels":[{"name":"initiative"}],"body":"## Goal\nx\n","parent":null},
  "31": {"number":31,"title":"A","state":"OPEN","labels":[],"body":"## Goal\nx\n## Scope\n`src/a.txt`\n## Plan\n### Allowed paths\n- `src/a.txt`\n","parent":{"number":30}},
  "35": {"number":35,"title":"Integration","state":"OPEN","labels":[],"body":"## Goal\nx\n","parent":null},
  "32": {"number":32,"title":"B","state":"OPEN","labels":[],"body":"## Goal\nx\n## Scope\n`src/b.txt`\n","parent":{"number":30}},
  "33": {"number":33,"title":"C","state":"OPEN","labels":[],"body":"## Goal\nx\n## Scope\n`src/c.txt`\n","parent":null},
  "34": {"number":34,"title":"D","state":"CLOSED","labels":[],"body":"## Goal\nx\n","parent":{"number":30}},
  "36": {"number":36,"title":"Unlabelled","state":"OPEN","labels":[],"body":"## Goal\nx\n","parent":null},
  "37": {"number":37,"title":"F","state":"OPEN","labels":[],"body":"## Goal\nx\n## Scope\n`src/f.txt`\n","parent":{"number":36}}}'
export BLOCKERS='{"32":[{"number":31,"state":"OPEN","stateReason":null,"title":"A"}]}'
export CHILDREN='{}' PRS='[]'
g() { PATH="$tmp/gh5:$PATH" "$S/gate.sh" "$@" 2>&1; }
out=$(g work 33); rc=$?; [ "$rc" -eq 0 ] && has "$out" '^kind: task$' && has "$out" '^base: main$' && has "$out" 'create wip/33-c from origin/main' && ok || bad "gate work: a plain task's base is the trunk (exit $rc): $out"
out=$(g work 30); rc=$?; [ "$rc" -eq 1 ] && has "$out" 'BLOCKED: #30 is a parent' && ok || bad "gate work: a parent has no branch (exit $rc): $out"
out=$(g work 31); rc=$?; [ "$rc" -eq 0 ] && has "$out" '^kind: child of #30$' && has "$out" '^base: wip/30-integration (integration branch of #30, created from origin/main)$' && has "$out" 'create wip/31-a from origin/wip/30-integration' && ok || bad "gate work: a child's base is the integration branch, created on first use (exit $rc): $out"
git ls-remote --heads "$tmp/i-origin" | grep -q 'refs/heads/wip/30-integration$' && [ "$(git rev-parse origin/wip/30-integration)" = "$(git rev-parse origin/main)" ] && ok || bad "gate work: the integration branch exists on origin at the trunk's commit"
out=$(g work 31); has "$out" '^base: wip/30-integration (integration branch of #30)$' && ok || bad "gate work: an existing integration branch is reused, not recreated: $out"
# a child of a parent without the label: ci.sh and the ship gate would never treat the branch as a parent's, so no branch yet
out=$(g work 37); rc=$?
[ "$rc" -eq 1 ] && has "$out" '^kind: child of #36$' && has "$out" "BLOCKED: parent #36 has no 'initiative' label.*issue.sh ensure-label initiative && gh issue edit 36 --add-label initiative" && ok || bad "gate work: a child of an unlabelled parent is blocked with the label command named (exit $rc): $out"
git ls-remote --heads "$tmp/i-origin" | grep -q 'wip/36-integration' && bad "gate work: the integration branch was created for an unlabelled parent" || ok
out=$(g work 32); rc=$?; [ "$rc" -eq 1 ] && has "$out" 'BLOCKED: a blocker is not closed as completed' && ok || bad "gate work: a child blocked by an open sibling (exit $rc): $out"
export BLOCKERS='{"32":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"}]}'
out=$(g work 32); rc=$?; [ "$rc" -eq 0 ] && has "$out" '^base: wip/30-integration' && ok || bad "gate work: the sibling closed as completed unblocks (exit $rc): $out"
# the child's PR: into the integration branch, merged without a question
# pr <number> <title> <state> _ _ <head> <base> <files>: sets PRS to that one PR, in gh's shape
pr() { PRS=$(printf '[{"number":%s,"title":"%s","url":"u/%s","state":"%s","isDraft":true,"body":"","updatedAt":"2026-01-01T00:00:00Z","mergeable":"MERGEABLE","headRefOid":"%s","headRefName":"%s","baseRefName":"%s","files":%s,"reviews":[],"commits":[{"committedDate":"2026-01-01T00:00:00Z"}],"statusCheckRollup":[]}]' "$1" "$2" "$1" "$3" "$(git rev-parse "$6")" "$6" "$7" "$(printf '%s' "$8" | jq -c 'map({path: .})')"); export PRS; }
mkrec() { printf '# %s — %s\nIssue: #%s\n\n## Asked\nDo %s.\n\n## Done when\nIt is done.\n\n## Explicitly not\nnone\n\n## Decisions made along the way\n- none\n\n## Deviations / notes\n- none\n' "$1" "$2" "$1" "$2" > "docs/tasks/$1-$3.md"; }
git checkout -q -b wip/31-a origin/wip/30-integration && mkdir -p src docs/tasks && echo a > src/a.txt && mkrec 31 A a
git add -A && git commit -qm "a" && git push -q -u origin wip/31-a
pr 101 '[31] A' OPEN _ _ wip/31-a wip/30-integration '["docs/tasks/31-a.md","src/a.txt"]'
out=$(g ship 31); rc=$?; [ "$rc" -eq 0 ] && has "$out" '^merge: automatic (into wip/30-integration; the human.s gate is /t-ship 30)$' && has "$out" '^record: docs/tasks/31-a.md$' && has "$out" 'wip/31-a → wip/30-integration' && ok || bad "gate ship: a child's PR into the integration branch merges automatically (exit $rc): $out"
pr 101 '[31] A' OPEN _ _ wip/31-a main '["docs/tasks/31-a.md","src/a.txt"]'
out=$(g ship 31); rc=$?; [ "$rc" -eq 1 ] && has "$out" "BLOCKED: PR base is main; a child's PR merges into wip/30-integration" && ok || bad "gate ship: a child's PR against the trunk is refused (exit $rc): $out"
# the parent's PR: the integration branch to the trunk, after the children landed
git checkout -q -B wip/30-integration origin/wip/30-integration && git merge -q --squash wip/31-a && git commit -qm "[31] A (#101)"
echo b > src/b.txt && mkrec 32 B b && git add -A && git commit -qm "[32] B (#104)" && git push -q origin wip/30-integration
git checkout -q main
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"OPEN","stateReason":null,"title":"B"}]}'
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md","docs/tasks/32-b.md","src/a.txt","src/b.txt"]'
out=$(g ship 30); rc=$?; [ "$rc" -eq 1 ] && has "$out" '^merge: confirm$' && has "$out" 'BLOCKED: child #32 is still open' && has "$out" '^record: docs/tasks/31-a.md$' && ok || bad "gate ship: a parent blocks while a child is open (exit $rc): $out"
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"CLOSED","stateReason":"COMPLETED","title":"B"}]}'
out=$(g ship 30); rc=$?; [ "$rc" -eq 0 ] && has "$out" '^kind: parent$' && has "$out" '^record: docs/tasks/32-b.md$' && ! has "$out" 'Plan' && ok || bad "gate ship: every child closed as completed with its record → the parent may ship, no plan asked (exit $rc): $out"
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md","src/a.txt","src/b.txt"]'
out=$(g ship 30); rc=$?; [ "$rc" -eq 1 ] && has "$out" 'BLOCKED: completed child #32 has no record' && ok || bad "gate ship: a completed child whose record is not in the diff blocks (exit $rc): $out"
# a child that merged into the trunk itself, under a release without integration branches: its record is on the trunk, not in the diff
mkdir -p docs/tasks && mkrec 36 E e && git add -A && git commit -qm "[36] E (#99)" && git push -q origin main && git fetch -q origin
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"CLOSED","stateReason":"COMPLETED","title":"B"},{"number":36,"state":"CLOSED","stateReason":"COMPLETED","title":"E"}]}'
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md","docs/tasks/32-b.md","src/a.txt","src/b.txt"]'
out=$(g ship 30); rc=$?; [ "$rc" -eq 0 ] && has "$out" '^record: docs/tasks/36-e.md (already on main' && ok || bad "gate ship: a completed child whose record is already on the trunk ships (exit $rc): $out"
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"CLOSED","stateReason":"COMPLETED","title":"B"},{"number":34,"state":"CLOSED","stateReason":"NOT_PLANNED","title":"D"}]}'
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md","docs/tasks/32-b.md","docs/tasks/34-d.md","src/a.txt","src/b.txt"]'
out=$(g ship 30); rc=$?; [ "$rc" -eq 1 ] && has "$out" 'BLOCKED: cancelled child #34 is still on wip/30-integration' && ok || bad "gate ship: a cancelled child still on the branch blocks (exit $rc): $out"
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md","docs/tasks/32-b.md","src/a.txt","src/b.txt"]'
out=$(g ship 30); rc=$?; [ "$rc" -eq 0 ] && ok || bad "gate ship: a cancelled child whose revert landed is fine (exit $rc): $out"
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md","docs/tasks/32-b.md",".claude/skills/x/SKILL.md"]'
out=$(g ship 30); rc=$?; [ "$rc" -eq 1 ] && has "$out" 'BLOCKED: protected diff with no cold review' && ! has "$out" "no '## Plan'" && ok || bad "gate ship: a protected combined diff needs the review, never a plan on the parent (exit $rc): $out"
export PRS='[]'
out=$(g ship 30); rc=$?; [ "$rc" -eq 1 ] && has "$out" 'BLOCKED: no PR for #30 — open the integration PR: gh pr create --draft --base main --head wip/30-integration --title "\[30\] Init"' && ok || bad "gate ship: a parent with no PR names the command that opens it (exit $rc): $out"
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '[]'; export CHILDREN='{"30":[]}'
out=$(g ship 30); rc=$?; [ "$rc" -eq 1 ] && has "$out" 'BLOCKED: #30 has no children' && ok || bad "gate ship: a parent without children (exit $rc): $out"
git checkout -q -b wip/33-c origin/main && mkdir -p docs/tasks && mkrec 33 C c
git add -A && git commit -qm c && git push -q -u origin wip/33-c && git checkout -q main
pr 103 '[33] C' OPEN _ _ wip/33-c main '["docs/tasks/33-c.md"]'
out=$(g ship 33); rc=$?; [ "$rc" -eq 0 ] && has "$out" '^merge: confirm$' && has "$out" '^record: docs/tasks/33-c.md$' && ok || bad "gate ship: a plain task still asks the human (exit $rc): $out"

echo "# ci.sh: a child's PR and the initiative's PR"
ci5() { BASE_REF="$1" HEAD_REF="$2" PR_NUMBER="$3" PR_TITLE="$4" GH_TOKEN=x PATH="$tmp/gh5:$PATH" "$S/ci.sh" 2>&1; }
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"CLOSED","stateReason":"COMPLETED","title":"B"}]}' BLOCKERS='{}'
out=$(PR_REF=wip/31-a ci5 wip/30-integration wip/31-a 101 "[31] A"); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'policy: exempt/protected/docs from origin/wip/30-integration' && has "$out" 'OK: record docs/tasks/31-a.md' && has "$out" 'OK: not a protected diff' && ok || bad "ci: a child's PR is judged by today's rules from its base, the integration branch (exit $rc): $out"
out=$(PR_REF=wip/30-integration ci5 main wip/30-integration 102 "[30] Init"); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'OK: record docs/tasks/31-a.md' && has "$out" 'OK: record docs/tasks/32-b.md' && has "$out" 'OK: title starts with \[30\]' && ! has "$out" 'no record docs/tasks/30-' && ok || bad "ci: the initiative's PR is judged by its children's records, not its own (exit $rc): $out"
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":36,"state":"CLOSED","stateReason":"COMPLETED","title":"E"}]}'
out=$(PR_REF=wip/30-integration ci5 main wip/30-integration 102 "[30] Init"); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'OK: record docs/tasks/36-e.md of completed child #36 is already on main' && ok || bad "ci: a completed child whose record is already on the trunk passes (exit $rc): $out"
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":38,"state":"CLOSED","stateReason":"COMPLETED","title":"G"}]}'
out=$(PR_REF=wip/30-integration ci5 main wip/30-integration 102 "[30] Init"); rc=$?
[ "$rc" -eq 1 ] && has "$out" 'FAIL: completed child #38 has no record docs/tasks/38-<slug>.md in this PR or on main' && ok || bad "ci: a completed child with a record nowhere still fails (exit $rc): $out"
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"OPEN","stateReason":null,"title":"B"}]}'
out=$(PR_REF=wip/30-integration ci5 main wip/30-integration 102 "[30] Init"); rc=$?
[ "$rc" -eq 1 ] && has "$out" 'FAIL: child #32 (B) is still open' && ok || bad "ci: an open child fails the initiative's PR (exit $rc): $out"
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"CLOSED","stateReason":"NOT_PLANNED","title":"B"}]}'
out=$(PR_REF=wip/30-integration ci5 main wip/30-integration 102 "[30] Init"); rc=$?
[ "$rc" -eq 1 ] && has "$out" 'FAIL: cancelled child #32 is still on wip/30-integration' && ok || bad "ci: a cancelled child still in the diff fails (exit $rc): $out"
git checkout -q -b wip/30-prot origin/wip/30-integration && mkdir -p .claude/skills/x && echo x > .claude/skills/x/SKILL.md && git add -A && git commit -qm prot -q
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"CLOSED","stateReason":"COMPLETED","title":"B"}]}'
pr 102 '[30] Init' OPEN _ _ wip/30-prot main '[]'
out=$(PR_REF=wip/30-prot ci5 main wip/30-integration 102 "[30] Init"); rc=$?
[ "$rc" -eq 1 ] && has "$out" "OK: a parent's plans are its children's" && has "$out" 'FAIL: protected diff needs a cold review' && ok || bad "ci: a protected combined diff needs the review, never a plan on the parent (exit $rc): $out"
# a task whose slug is exactly "integration" is a task: the label decides, not the branch
git checkout -q -b wip/35-integration origin/main && mkrec 35 Integration integration && git add -A && git commit -qm i -q
out=$(PR_REF=wip/35-integration ci5 main wip/35-integration 105 "[35] Integration"); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'OK: record docs/tasks/35-integration.md' && ! has "$out" 'children' && ok || bad "ci: a task called Integration is judged as a task (exit $rc): $out"
# /t-cancel's revert of a child already on the integration branch: the record goes, and that is accepted only for a cancelled issue
git checkout -q -b wip/31-revert origin/wip/30-integration && git rm -q docs/tasks/31-a.md src/a.txt && git commit -qm "revert a" -q
out=$(PR_REF=wip/31-revert ci5 wip/30-integration wip/31-revert 106 "[31] Revert: A"); rc=$?
[ "$rc" -eq 1 ] && has "$out" 'FAIL: record docs/tasks/31-a.md is deleted in this PR, and #31 is not cancelled' && ok || bad "ci: a PR that deletes the record of an open task fails (exit $rc): $out"
ISSUES=$(printf '%s' "$ISSUES" | jq -c '.["31"] += {state: "CLOSED", stateReason: "NOT_PLANNED"}'); export ISSUES
out=$(PR_REF=wip/31-revert ci5 wip/30-integration wip/31-revert 106 "[31] Revert: A"); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'OK: record docs/tasks/31-a.md removed by the revert of cancelled #31' && ok || bad "ci: the revert of a cancelled child passes with its record deleted (exit $rc): $out"
# a parent's PR whose diff deletes a child's record: judged by that child's issue, not the parent's
git checkout -q -b wip/30-del origin/wip/30-integration && git rm -q docs/tasks/31-a.md && git commit -qm "drop 31" -q
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"NOT_PLANNED","title":"A"}]}'
out=$(PR_REF=wip/30-del ci5 wip/30-integration wip/30-integration 107 "[30] Init"); rc=$?
[ "$rc" -eq 0 ] && has "$out" 'OK: record docs/tasks/31-a.md removed by the revert of cancelled #31' && ok || bad "ci: a parent's PR deleting a cancelled child's record passes (exit $rc): $out"
git checkout -q -b wip/30-del2 origin/wip/30-integration && git rm -q docs/tasks/32-b.md && git commit -qm "drop 32" -q
ISSUES=$(printf '%s' "$ISSUES" | jq -c '.["32"] += {state: "CLOSED", stateReason: "COMPLETED"}'); export ISSUES
export CHILDREN='{"30":[{"number":32,"state":"CLOSED","stateReason":"COMPLETED","title":"B"}]}'
out=$(PR_REF=wip/30-del2 ci5 wip/30-integration wip/30-integration 107 "[30] Init"); rc=$?
[ "$rc" -eq 1 ] && has "$out" 'FAIL: record docs/tasks/32-b.md is deleted in this PR, and #32 is not cancelled' && ok || bad "ci: a parent's PR deleting a completed child's record fails on that child's state (exit $rc): $out"
ISSUES=$(printf '%s' "$ISSUES" | jq -c '.["32"] += {state: "OPEN", stateReason: null}'); export ISSUES
git checkout -q main

echo "# snapshot.sh review / status for an initiative (stubbed gh)"
sn() { PATH="$tmp/gh5:$PATH" "$S/snapshot.sh" "$@" 2>&1; }
export CHILDREN='{"30":[{"number":31,"state":"CLOSED","stateReason":"COMPLETED","title":"A"},{"number":32,"state":"CLOSED","stateReason":"COMPLETED","title":"B"}]}'
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md","docs/tasks/32-b.md","src/a.txt","src/b.txt"]'
out=$(sn review 30); rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s' "$out" | jq -r '.children | length')" = 2 ] && [ "$(printf '%s' "$out" | jq -r '.children[0].record')" = docs/tasks/31-a.md ] && printf '%s' "$out" | jq -r '.children[0].plan' | grep -q '^- `src/a.txt`$' && [ "$(printf '%s' "$out" | jq -r '.children[1].plan')" = "" ] && [ "$(printf '%s' "$out" | jq -r '.pr.baseRefName')" = main ] && ok || bad "snapshot review: an initiative carries its children with their plans and records (exit $rc): $out"
pr 101 '[31] A' OPEN _ _ wip/31-a wip/30-integration '["docs/tasks/31-a.md"]'
out=$(sn review 31); rc=$?
[ "$rc" -eq 0 ] && [ "$(printf '%s' "$out" | jq -r '.children | length')" = 0 ] && ok || bad "snapshot review: a child has no children (exit $rc): $out"
pr 102 '[30] Init' OPEN _ _ wip/30-integration main '["docs/tasks/31-a.md"]'
export BLOCKERS='{"32":[{"number":31,"state":"CLOSED","stateReason":"NOT_PLANNED","title":"A"}]}'
out=$(sn status)
has "$out" '^- #30 Init · integration branch · PR #102 draft, checks none, review none$' && has "$out" '^- #32 B · part of #30 · blocked by #31$' && ! has "$out" 'wip/30-integration has no open issue' && has "$out" '^- branch wip/31-a has no open issue$' && ok || bad "snapshot status: a parent shows its integration branch and PR; a cancelled child's stale branch is a warning: $out"
git checkout -q main; unset ISSUES BLOCKERS CHILDREN PRS

echo "# footprint (informational)"
bytes=$(cd "$tmp/b" && git ls-files -s -o --exclude-standard | awk '$1!="120000"{print $NF}' | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}')
echo "consumer footprint: ${bytes:-?} bytes"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
