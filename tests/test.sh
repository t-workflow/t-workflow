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
sedi() { local f="${@: -1}"; sed -i.bak "$@" && rm -f "$f.bak"; }   # in-place sed, portable, no backup left
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# A consumer-shaped repo to run the scripts in (config from the installer, not this repo's).
mk_repo() { # <dir> [check]
  mkdir -p "$1" && (cd "$1" && git init -q -b main && git commit -q --allow-empty -m init) || return 1
  bash "$ROOT/install.sh" v0.0.0-test --from "$ROOT" --dir "$1" --no-pr >/dev/null 2>&1 || return 1
}

echo "# protected.sh / docs-only.sh"
mk_repo "$tmp/a" || bad "install into a fresh repo"
cd "$tmp/a"
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
cd "$tmp/a"; mkdir -p docs/tasks
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

echo "# lib.sh helpers"
# shellcheck disable=SC1091
. "$S/lib.sh"
[ "$(slugify 'Add /t-config: a Skill!! ')" = "add-t-config-a-skill" ] && ok || bad "slugify"
[ "$(slugify "$(printf 'x%.0s' $(seq 60))")" = "$(printf 'x%.0s' $(seq 40))" ] && ok || bad "slugify truncates to 40"
printf '## A\none\n## Plan\nallowed\n\n## B\nb\n' | section Plan | grep -q '^allowed$' && ok || bad "section extracts a body"
[ "$(printf '## Plan\n## Plan\n' | count_sections Plan)" = 2 ] && ok || bad "count_sections"
reviews='[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: subagent\n## Pending human checks\n- none\nreadiness: ready"},{"submittedAt":"2026-01-02T00:00:00Z","body":"isolation: fresh session\nreadiness: not-ready"}]'
rvp=$(review_verdict '[{"submittedAt":"2026-01-01T00:00:00Z","body":"isolation: subagent\n## Findings\n- x\n## Pending human checks\n- check the colours\nreadiness: ready"}]' "")
has "$rvp" '^  - check the colours$' && ok || bad "review_verdict: pending checks listed"
printf '%s' "$rvp" | grep -q 'readiness' && bad "review_verdict: readiness line leaks into pending checks" || ok
rv=$(review_verdict "$reviews" "2026-01-01T12:00:00Z"); rv3=$(review_verdict "$reviews" "2026-01-03T00:00:00Z"); rv0=$(review_verdict '[]' "")
has "$rv" '^verdict: not-ready$' && ok || bad "review_verdict: latest wins"
has "$rv3" '^fresh: no$' && ok || bad "review_verdict: stale when head is newer"
has "$rv" '^fresh: yes$' && ok || bad "review_verdict: fresh"
has "$rv" '^pending: unknown$' && ok || bad "review_verdict: missing pending section is unknown"
has "$rv0" '^verdict: none$' && ok || bad "review_verdict: none"

echo "# install.sh"
mk_repo "$tmp/b" && ok || bad "install: adopt"
cd "$tmp/b"
[ "$(cat .t-workflow/VERSION)" = v0.0.0-test ] && ok || bad "install: VERSION"
[ -L CLAUDE.md ] && [ -L GEMINI.md ] && [ -L .agents/skills ] && ok || bad "install: symlinks"
grep -q '^check=""' .t-workflow/config && ok || bad "install: pristine config, not this repo's"
head -1 AGENTS.md | grep -q '.t-workflow/AGENTS.md' && ok || bad "install: AGENTS.md pointer"
for p in .t-workflow/scripts/gate.sh .claude/skills/t-work/SKILL.md .github/workflows/t-workflow.yml docs/tasks/TEMPLATE.md; do [ -e "$p" ] || bad "install: missing $p"; done; ok
[ ! -e tests ] && [ ! -e install.sh ] && [ ! -e CHANGELOG.md ] && ok || bad "install: repo-only files leaked"
# a real CLAUDE.md becomes AGENTS.md with the pointer prepended
mkdir -p "$tmp/c" && (cd "$tmp/c" && git init -q -b main && printf '# App\nDo X.\n' > CLAUDE.md && echo '{}' > package.json && git add -A && git commit -qm i)
bash "$ROOT/install.sh" v1 --from "$ROOT" --dir "$tmp/c" --no-pr >/dev/null 2>&1 || bad "install: with CLAUDE.md"
grep -q '^Do X.$' "$tmp/c/AGENTS.md" && head -1 "$tmp/c/AGENTS.md" | grep -q t-workflow && [ -L "$tmp/c/CLAUDE.md" ] && ok || bad "install: CLAUDE.md content kept under the pointer"
grep -q '^check="npm test"' "$tmp/c/.t-workflow/config" && ok || bad "install: check detected from package.json"
out=$(bash "$ROOT/install.sh" v1 --from "$ROOT" --dir "$tmp/c" --no-pr 2>&1); has "$out" "already at v1" && ok || bad "install: same tag is a no-op"
# update keeps consumer-owned files, replaces owned ones
(cd "$tmp/c" && echo 'hand edit' >> .claude/skills/t-open/SKILL.md && sedi 's/^check=.*/check="mine"/' .t-workflow/config && echo "mine" >> AGENTS.md && git add -A && git commit -qm c)
(cd "$tmp/c" && grep -v '^exempt=' .t-workflow/config | perl -pe 'chomp if eof' > cfg && mv cfg .t-workflow/config && git add -A && git commit -qm "drop a key")
out=$(bash "$ROOT/install.sh" v2 --from "$ROOT" --dir "$tmp/c" --no-pr 2>&1) || bad "install: update: $out"
(cd "$tmp/c" && [ "$(cat .t-workflow/VERSION)" = v2 ] && grep -q '^check="mine"' .t-workflow/config && grep -q '^mine$' AGENTS.md && ! grep -q 'hand edit' .claude/skills/t-open/SKILL.md) && ok || bad "install: update replaced owned files and kept consumer ones"
(cd "$tmp/c" && grep -q '^exempt=""' .t-workflow/config && grep -B1 '^exempt=""' .t-workflow/config | head -1 | grep -q '^# Branch globs') && has "$out" 'config: added exempt' && ok || bad "install: update appends a missing config key with its comment"
[ "$(grep -c '^check=' "$tmp/c/.t-workflow/config")" = 1 ] && ok || bad "install: update does not duplicate present keys"
(cd "$tmp/c" && grep -B1 '^# Branch globs' .t-workflow/config | head -1 | grep -q '^$') && ok || bad "install: appended key is separated by a blank line even when the config lacked a trailing newline"
# a git source: no tag means the newest tag; a tag means that tag
git clone -q --bare "$ROOT" "$tmp/src.git" && git -C "$tmp/src.git" tag v0.0.1 && git -C "$tmp/src.git" tag v0.0.10 && git -C "$tmp/src.git" tag v0.0.2 && git -C "$tmp/src.git" tag rel/v0.0.3
mkdir -p "$tmp/f" && (cd "$tmp/f" && git init -q -b main && git commit -q --allow-empty -m i)
out=$(bash "$ROOT/install.sh" --from "file://$tmp/src.git" --dir "$tmp/f" --no-pr 2>&1) || bad "install: git source, no tag: $out"
[ "$(cat "$tmp/f/.t-workflow/VERSION")" = v0.0.10 ] && ok || bad "install: newest tag by version order, got $(cat "$tmp/f/.t-workflow/VERSION")"
out=$(bash "$ROOT/install.sh" v0.0.2 --from "file://$tmp/src.git" --dir "$tmp/f" --no-pr 2>&1) || bad "install: git source, explicit tag: $out"
[ "$(cat "$tmp/f/.t-workflow/VERSION")" = v0.0.2 ] && has "$out" 'changes from v0.0.10 to v0.0.2' && ok || bad "install: explicit tag and log between tags"
out=$(bash "$ROOT/install.sh" rel/v0.0.3 --from "file://$tmp/src.git" --dir "$tmp/f" --no-pr 2>&1) || bad "install: tag with a slash: $out"
[ "$(cat "$tmp/f/.t-workflow/VERSION")" = rel/v0.0.3 ] && ok || bad "install: a tag containing / is kept whole, got $(cat "$tmp/f/.t-workflow/VERSION")"
out=$(bash "$ROOT/install.sh" --from "$ROOT" --dir "$tmp/f" --no-pr 2>&1); has "$out" 'a tag is required' && ok || bad "install: local directory needs a tag"
out=$(bash "$ROOT/install.sh" --from "file://$tmp/nowhere.git" --dir "$tmp/f" --no-pr 2>&1); has "$out" 'could not list tags' && ok || bad "install: unreachable source reports the real failure, not 'no tags': $out"
# replace: the old template layout with a manifest and filled slots
mkdir -p "$tmp/d/.github/workflows" "$tmp/d/.claude/skills/t-config" "$tmp/d/.claude/skills/l-mine" "$tmp/d/.t-workflow/scripts" "$tmp/d/migrations" "$tmp/d/docs/adr" "$tmp/d/docs/tasks/000100"
cd "$tmp/d" && git init -q -b main
printf '# AGENTS.md\n\n## The pipeline\n<!-- local -->\n*(reserved: consumer-local skills — get a row here,\nonce added.)*\n<!-- /local -->\n## Reviewer model\n<!-- local -->\nDefault reviewer model: opus\n<!-- /local -->\n## Checks\n<!-- local -->\n1. `make test` — the build\n<!-- /local -->\n### Documentation-only paths\n<!-- local -->\n- `site/**`\n<!-- /local -->\n## Project notes\n<!-- local -->\nUse rubocop.\n<!-- /local -->\n' > AGENTS.md
printf '# CONSTITUTION.md\n<!-- local -->\n**Status note:** phase 0.\n<!-- /local -->\n## 3. Protected surfaces\n- `docs/adr/`\n<!-- local -->\n- `db/migrate/`\n<!-- /local -->\n## 4. Stack & architecture\n<!-- local -->\n- Rails only.\n<!-- /local -->\n' > CONSTITUTION.md
printf 'node_modules\n# <!-- local -->\n.env\n# <!-- /local -->\n' > .gitignore
echo old > .claude/skills/t-config/SKILL.md; echo mine > .claude/skills/l-mine/SKILL.md; echo old > .t-workflow/scripts/x.sh
printf 'name: CI\n# <!-- local -->\n      - run: make lint\n# <!-- /local -->\n' > .github/workflows/ci.yml
echo v1 > migrations/V1__x.md; echo adr > docs/adr/001-old.md; echo mine > docs/adr/100-mine.md; echo rec > docs/tasks/000100/101-x.md; echo t > docs/tasks/TEMPLATE.md
ln -s AGENTS.md CLAUDE.md; mkdir -p .agents && ln -s ../.claude/skills .agents/skills
printf '{"files":{"AGENTS.md":{},"CONSTITUTION.md":{},".gitignore":{},".claude/skills/t-config/SKILL.md":{},".t-workflow/scripts/x.sh":{},".github/workflows/ci.yml":{},"docs/adr/001-old.md":{},"docs/tasks/TEMPLATE.md":{},"CLAUDE.md":{},".agents/skills":{}}}' > .template-manifest.json
git add -A && git commit -qm old
bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/d" --no-pr >/dev/null 2>&1 || bad "install: replace"
[ ! -e .template-manifest.json ] && [ ! -e migrations ] && [ ! -e CONSTITUTION.md ] && [ ! -e .github/workflows/ci.yml ] && [ ! -e docs/adr/001-old.md ] && [ ! -e .claude/skills/t-config ] && ok || bad "replace: old files removed"
[ -f docs/adr/100-mine.md ] && [ -f docs/tasks/000100/101-x.md ] && [ -f .claude/skills/l-mine/SKILL.md ] && ok || bad "replace: consumer files kept"
grep -q '^check="make test"' .t-workflow/config && grep -q '^protected="db/migrate/"' .t-workflow/config && grep -q '^docs="site/\*\*"' .t-workflow/config && grep -q '^reviewer_model="opus"' .t-workflow/config && ok || bad "replace: slots into config: $(grep -vE '^#|^$' .t-workflow/config | tr '\n' ' ')"
grep -q '^Use rubocop.$' AGENTS.md && grep -q '^- Rails only.$' AGENTS.md && ok || bad "replace: notes and constraints into AGENTS.md"
grep -q '^\.env$' .gitignore && ! grep -q 'local -->' .gitignore && ok || bad "replace: gitignore kept, markers stripped"
grep -q 'make lint' .t-workflow/REPLACED.md && ! grep -q 'consumer-local skills' .t-workflow/REPLACED.md && ok || bad "replace: ci slot reported, placeholder not"
[ -L CLAUDE.md ] && [ -L .agents/skills ] && ok || bad "replace: aliases restored"
printf '{"files":{}}' > .template-manifest.json
out=$(bash "$ROOT/install.sh" v3 --from "$ROOT" --dir "$tmp/d" --no-pr 2>&1); has "$out" "lists no files" && ok || bad "replace: refuses an empty manifest"

echo "# ci.sh (offline parts)"
mkdir -p "$tmp/e" && (cd "$tmp/e" && git init -q -b main && echo base > base.txt && git add -A && git commit -qm init && git clone -q --bare . "$tmp/e-origin" && git remote add origin "$tmp/e-origin" && git fetch -q origin)
bash "$ROOT/install.sh" v0 --from "$ROOT" --dir "$tmp/e" --no-pr >/dev/null 2>&1 || bad "ci fixture: install"
cd "$tmp/e" && git add -A && git commit -qm adopt
mkdir -p "$tmp/bin"; printf '#!/bin/sh\nexit 1\n' > "$tmp/bin/gh"; chmod +x "$tmp/bin/gh"
ci() { BASE_REF=main HEAD_REF="$1" PR_NUMBER=1 PR_TITLE="$2" GH_TOKEN=x PATH="$tmp/bin:$PATH" "$S/ci.sh" 2>&1; }
# base (origin/main) has no t-workflow yet: adoption PR
out=$(ci wip/5-thing "[5] Thing"); has "$out" 'adoption PR' && ok || bad "ci: base without t-workflow is an adoption PR: $out"
has "$out" 'no check command configured' && ok || bad "ci: no check configured"
# now the base carries t-workflow: the gates are in force
git push -q origin main; git fetch -q origin
git checkout -q -b wip/5-thing
sed 's/7/5/g; s/Fixture/Thing/; s/<the goal, from the issue>/Do it./; s/^## Ask$/## Asked/' "$tmp/a/docs/tasks/7-fixture.md" > docs/tasks/5-thing.md
echo x > file.txt; git add -A; git commit -qm work
out=$(ci wip/5-thing "Thing")
has "$out" 'OK: record docs/tasks/5-thing.md' && ok || bad "ci: record ok: $out"
has "$out" "FAIL: PR title must start with '\[5\] '" && ok || bad "ci: title fail: $out"
has "$out" 'FAIL: cannot read issue #5' && ok || bad "ci: tracker unreachable is a failure, not a pass"
out=$(ci feature/x x); has "$out" 'is not wip/<id>-<slug>' && ok || bad "ci: non-task branch fails"
sedi 's|^exempt=""|exempt="dependabot/* feature/*"|' .t-workflow/config
out=$(ci feature/x x); has "$out" 'exempt from the task gates' && ok || bad "ci: exempt branch"
sedi 's|^check=""|check="test -f file.txt"|' .t-workflow/config
out=$(ci feature/x x); has "$out" 'check 1 passed' && ok || bad "ci: check 1 runs and passes: $out"
sedi 's|^check=.*|check="false"|' .t-workflow/config
if ci feature/x x >/dev/null; then bad "ci: failing check 1 must fail"; else ok; fi
git checkout -q -- . 2>/dev/null; git checkout -q main; git checkout -q -b wip/6-docs; echo "# 6 — Docs" > docs/tasks/6-docs.md; git add -A; git commit -qm docs
sedi 's|^check=.*|check="false"|' .t-workflow/config
out=$(ci wip/6-docs "[6] Docs"); has "$out" 'check 1 skipped: documentation-only diff' && ok || bad "ci: docs-only skip: $out"

echo "# footprint (informational)"
bytes=$(cd "$tmp/b" && git ls-files -s -o --exclude-standard | awk '$1!="120000"{print $NF}' | xargs wc -c 2>/dev/null | tail -1 | awk '{print $1}')
echo "consumer footprint: ${bytes:-?} bytes"

echo
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
