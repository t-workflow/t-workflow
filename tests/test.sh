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
for p in .t-workflow/scripts/gate.sh .claude/skills/t-work/SKILL.md .github/workflows/t-workflow.yml .github/ISSUE_TEMPLATE/task.yml docs/tasks/TEMPLATE.md; do [ -e "$p" ] || bad "install: missing $p"; done; ok
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
(cd "$tmp/c" && sed -i.bak 's|^# Build/test command the agent runs locally.*|# Build/test command, run as check 1 (empty = no check 1 yet).|; /^# CI does not run it/d; s|^# Branch globs exempt.*|# Branch globs exempt from the task gates in CI (e.g. "dependabot/*"). Check 1 still runs.|' .t-workflow/config && rm -f .t-workflow/config.bak && git add -A && git commit -qm "old comments")
bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/c" --no-pr >/dev/null 2>&1 || bad "install: update (comments)"
(cd "$tmp/c" && grep -q '^# CI does not run it' .t-workflow/config && ! grep -q 'Check 1 still runs' .t-workflow/config && grep -q '^check="mine"' .t-workflow/config) && ok || bad "install: update rewrites the old default comments and keeps the values: $(grep -E '^#|^check=' "$tmp/c/.t-workflow/config" | head -8)"
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
grep -q '^name: Task' .github/ISSUE_TEMPLATE/task.yml && ! grep -q '^old$' .github/ISSUE_TEMPLATE/task.yml && ok || bad "replace (no manifest): the old task form is replaced by the owned one"
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
cfgvals=$(cd "$tmp/cfg" && . "$S/lib.sh" && printf 'check=%s protected=%s exempt=%s docs=%s reviewer=%s' "$check" "$protected" "$exempt" "$docs" "$reviewer_model")
[ "$cfgvals" = "check=tests/test.sh protected=db/migrate/* exempt= docs= reviewer=" ] && ok || bad "config: plain key=value lines parse, the rest is ignored: $cfgvals"
[ ! -e "$tmp/cfg-PWNED" ] && [ ! -e "$tmp/cfg-PWNED2" ] && ok || bad "config: a shell payload in the config never runs"
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

echo "# t-workflow.yml (trigger)"
wf="$ROOT/.github/workflows/t-workflow.yml"
grep -qE '^\s*pull_request_target:' "$wf" && ok || bad "workflow: must trigger on pull_request_target, not pull_request, so GitHub reads it from the base branch"
grep -qE '^\s*pull_request:' "$wf" && bad "workflow: pull_request trigger present — a PR could rewrite this file's own YAML on that trigger" || ok

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
out=$(RUNS='[{"databaseId":9,"status":"completed","conclusion":"failure"}]' RERUN_FAILS=1 rr); rc=$?
[ "$rc" -eq 1 ] && has "$out" 'could not re-run' && ok || bad "rerun-ci: reports a failed re-run (exit $rc): $out"
out=$(RUNS='' rr); rc=$?; [ "$rc" -eq 2 ] && has "$out" 'cannot list runs' && ok || bad "rerun-ci: a failed run list is an error, not 'no run' (exit $rc): $out"
out=$(PRVIEW='' rr); rc=$?; [ "$rc" -eq 2 ] && has "$out" 'cannot read PR' && ok || bad "rerun-ci: unreadable PR (exit $rc): $out"
grep -q 'pull_request_review' "$ROOT/.github/workflows/t-workflow.yml" && bad "workflow: still triggers on reviews" || ok

echo "# issue.sh children / blocking (stubbed gh, GitHub's real shape)"
mkdir -p "$tmp/gh3"
cat > "$tmp/gh3/gh" <<'STUB'
#!/usr/bin/env bash
# stub gh: returns GitHub's real JSON for the two fields, then applies the --jq expression the script passed
args=("$@"); expr=""; for i in "${!args[@]}"; do [ "${args[$i]}" = "--jq" ] && expr="${args[$((i+1))]}"; done
case "$*" in
  *"--json subIssues"*) json='{"subIssues":{"nodes":[{"id":"I_1","number":8,"state":"OPEN","title":"Step 1","url":"u"},{"id":"I_2","number":9,"state":"CLOSED","title":"Step 2","url":"u"}]}}' ;;
  *"--json blocking"*)  json='{"blocking":{"nodes":[{"id":"I_3","number":21,"state":"OPEN","title":"Step 14","url":"u"}]}}' ;;
  *) echo "stub: unexpected gh $*" >&2; exit 9 ;;
esac
if [ -n "$expr" ]; then printf '%s' "$json" | jq -c "$expr"; else printf '%s' "$json"; fi
STUB
chmod +x "$tmp/gh3/gh"
out=$(PATH="$tmp/gh3:$PATH" "$S/issue.sh" children 7 2>&1); [ "$out" = '[{"number":8,"title":"Step 1","state":"OPEN"},{"number":9,"title":"Step 2","state":"CLOSED"}]' ] && ok || bad "issue.sh children: $out"
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

echo "# footprint (informational)"
bytes=$(cd "$tmp/b" && git ls-files -s -o --exclude-standard | awk '$1!="120000"{print $NF}' | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}')
echo "consumer footprint: ${bytes:-?} bytes"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
