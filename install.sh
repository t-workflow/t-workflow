#!/usr/bin/env bash
# Install t-workflow into the current repository, update it to a newer release, or
# replace the old template-based t-workflow. One command; it opens the PR itself.
#
#   curl -fsSL https://raw.githubusercontent.com/t-workflow/t-workflow/main/install.sh | bash -s -- [<tag>] [options]
#
#   <tag>               the release to install; default: the newest tag at the source
#   --check "<cmd>"     the build/test command for .t-workflow/config (else detected from the repo)
#   --from <url|path>   where to take the release from (default: the t-workflow repository)
#   --dir <path>        the repository to install into (default: the current directory)
#   --no-protect        do not change GitHub branch protection or merge settings
#   --no-pr             change files only: no issue, branch, record, commit, PR, or protection
#
# Mode is detected: adopt (no t-workflow), update (.t-workflow/VERSION present), or
# replace (.template-manifest.json present — the old template-based t-workflow, whose
# owned files are removed and whose local slots are carried into the new layout).
set -euo pipefail

SOURCE_URL="https://github.com/t-workflow/t-workflow.git"
OWNED="
.t-workflow/AGENTS.md
.t-workflow/scripts
.claude/skills/t-open
.claude/skills/t-plan
.claude/skills/t-work
.claude/skills/t-review
.claude/skills/t-ship
.claude/skills/t-cancel
.claude/skills/t-status
.claude/skills/t-drive
.claude/skills/t-update
.github/workflows/t-workflow.yml
docs/tasks/TEMPLATE.md
"

note() { printf '%s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

tag=""; check_arg=""; from=""; dir="."; protect=yes; pr=yes
while [ $# -gt 0 ]; do
  case "$1" in
    --check) check_arg="$2"; shift 2 ;;
    --from) from="$2"; shift 2 ;;
    --dir) dir="$2"; shift 2 ;;
    --no-protect) protect=no; shift ;;
    --no-pr) pr=no; shift ;;
    -h|--help) sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option $1" ;;
    *) [ -z "$tag" ] && tag="$1" || die "unexpected argument $1"; shift ;;
  esac
done
source="${from:-$SOURCE_URL}"
if [ -z "$tag" ]; then
  [ -d "$source" ] && die "a tag is required with a local directory source"
  refs=$(git ls-remote --tags --refs "$source") || die "could not list tags at $source (see the error above)"
  tag=$(printf '%s\n' "$refs" | sed 's#^[0-9a-f]*[[:space:]]*refs/tags/##' | sort -V | tail -1)
  [ -n "$tag" ] || die "no tags at $source; pass one explicitly"
fi

cd "$dir" || die "no such directory: $dir"
git rev-parse --show-toplevel >/dev/null 2>&1 || die "$PWD is not a git repository"
cd "$(git rev-parse --show-toplevel)"

# --- mode -------------------------------------------------------------------------
if [ -f .template-manifest.json ]; then mode=replace
elif [ -f .t-workflow/VERSION ]; then mode=update
else mode=adopt; fi
current=""; [ "$mode" = update ] && current=$(cat .t-workflow/VERSION)
[ "$mode" = update ] && [ "$current" = "$tag" ] && { note "already at $tag; nothing to do"; exit 0; }
note "mode: $mode → $tag"

if [ "$pr" = yes ]; then
  command -v gh >/dev/null || die "gh is required (or use --no-pr)"
  gh auth status >/dev/null 2>&1 || die "gh is not authenticated (or use --no-pr)"
  [ -z "$(git status --porcelain)" ] || die "the working tree is not clean; commit or set aside your changes first"
fi

# --- source -----------------------------------------------------------------------
src=$(mktemp -d); trap 'rm -rf "$src"' EXIT
if [ -d "$source" ]; then
  note "source: $source (local directory, labelled $tag)"
  cp -R "$source"/. "$src"/
else
  note "source: $source at $tag"
  # Partial clone: full commit history (for the log between tags) but file contents
  # only for the tag checked out. A server without filter support falls back to a full clone.
  git clone -q --filter=blob:none --branch "$tag" "$source" "$src" || die "could not clone $tag"
fi
[ -f "$src/.t-workflow/AGENTS.md" ] || die "the source does not look like t-workflow"
if [ "$mode" = update ] && [ -d "$src/.git" ]; then
  note "changes from $current to $tag:"
  git -C "$src" log --oneline "$current..$tag" 2>/dev/null | sed 's/^/  /' || note "  (history between the two tags is not available)"
fi
trunk=$("$src/.t-workflow/scripts/trunk.sh")

# --- task: issue and branch --------------------------------------------------------
case "$mode" in
  adopt)   title="Adopt t-workflow $tag" ;;
  update)  title="Update t-workflow from $current to $tag" ;;
  replace) title="Replace the old t-workflow with t-workflow $tag" ;;
esac
id=""
if [ "$pr" = yes ]; then
  cur=$(git rev-parse --abbrev-ref HEAD)
  [ "$cur" = "$trunk" ] || die "run this from the trunk branch ($trunk); you are on $cur"
  git fetch -q origin
  body=$(mktemp)
  {
    echo "## Goal"
    case "$mode" in
      adopt)   echo "Install t-workflow $tag: the delivery workflow's skills, gate scripts, CI workflow, and record template, with this repository's own settings in \`.t-workflow/config\`." ;;
      update)  echo "Move t-workflow from $current to $tag by replacing every t-workflow-owned file with the release's copy. Consumer-owned files (\`AGENTS.md\`, \`.t-workflow/config\`) are untouched." ;;
      replace) echo "Remove the old template-based t-workflow (every file its manifest owns, its migrations, and its CI) and install t-workflow $tag in its place, carrying the old local slots into \`.t-workflow/config\` and \`AGENTS.md\`." ;;
    esac
    echo; echo "## Done when"
    echo "- \`.t-workflow/VERSION\` reads \`$tag\` and every path in the installer's owned set matches the release."
    echo "- \`.t-workflow/scripts/ci.sh\` passes on this PR."
    echo; echo "## Scope"
    echo "\`.t-workflow/\`, \`.claude/skills/t-*\`, \`.agents/skills\`, \`.github/workflows/t-workflow.yml\`, \`docs/tasks/\`, \`AGENTS.md\`, \`CLAUDE.md\`, \`GEMINI.md\`"
    echo; echo "## Non-goals"
    echo "- Changing anything else in the repository."
    echo; echo "## Plan"; echo "### Allowed paths"
    printf '%s\n' $OWNED | sed 's/^/- `/; s/$/`/'
    echo "- \`.t-workflow/config\`, \`AGENTS.md\`, \`CLAUDE.md\`, \`GEMINI.md\`, \`.agents/skills\`, \`docs/tasks/\` — created or pointed at t-workflow when absent"
    [ "$mode" = replace ] && echo "- every path in \`.template-manifest.json\`, \`migrations/\`, \`.gitignore\` (markers stripped) — removed or cleaned"
    echo "### Risks"; echo "- The detected check command may be wrong: read \`.t-workflow/config\` in the diff."
    [ "$mode" = replace ] && echo "- Old local-slot content that did not map onto the new layout is listed in \`.t-workflow/REPLACED.md\` for a human to place."
    echo "### Checks"; echo "- \`.t-workflow/scripts/ci.sh\` — record, title, plan, blockers, check 1"
    echo "### Human checks"; echo "- none"
  } > "$body"
  url=$(gh issue create --title "$title" --body-file "$body"); rm -f "$body"
  id="${url##*/}"
  slug=$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//' | cut -c1-40 | sed -E 's/-+$//')
  branch="wip/$id-$slug"
  git checkout -q -b "$branch" "origin/$trunk"
  note "issue #$id, branch $branch"
fi

# --- replace: remove the old template's files, keeping what its slots held --------
report=""
if [ "$mode" = replace ]; then
  command -v jq >/dev/null || die "jq is required to read .template-manifest.json"
  n=$(jq -r '.files | keys | length' .template-manifest.json 2>/dev/null || echo 0)
  [ "${n:-0}" -gt 0 ] || die ".template-manifest.json lists no files; nothing would be removed safely — inspect it first"
  report=$(mktemp)
  echo "# Replaced the old t-workflow" > "$report"
  echo >> "$report"; echo "Content the old local slots held that has no automatic place in the new layout. Place it by hand, then delete this file." >> "$report"
  old_check=""; old_docs=""; old_protected=""; old_model=""; old_notes=""; old_constraints=""
  slots() { # <file>: each marked region, preceded by "@@ <last ## heading>"
    awk '/^## /{h=$0} /^[[:space:]]*#?[[:space:]]*<!-- local -->[[:space:]]*$/{on=1; print "@@ " h; next}
         /^[[:space:]]*#?[[:space:]]*<!-- \/local -->[[:space:]]*$/{on=0; next} on{print}' "$1"
  }
  placeholder() { printf '%s' "$1" | grep -v '^[[:space:]]*$' | head -1 | grep -qE '^\*\(reserved'; }
  harvest() { # <file> <kind>
    local f="$1" kind="$2" h="" buf="" seen=no
    [ -f "$f" ] || return 0
    flush() {
      [ "$seen" = yes ] || return 0
      [ -n "$h" ] || h="(top of file)"
      placeholder "$buf" && return 0
      case "$kind:$h" in
        agents:"## Checks")
          if printf '%s' "$buf" | grep -qE '^1\. '; then old_check=$(printf '%s' "$buf" | grep -oE '`[^`]+`' | head -1 | tr -d '`')
          else old_docs=$(printf '%s' "$buf" | grep -oE '`[^`]+`' | tr -d '`' | tr '\n' ' '); fi ;;
        agents:"## Reviewer model") old_model=$(printf '%s' "$buf" | sed -n 's/^Default reviewer model: *//p' | grep -v '^(none' | head -1 || true) ;;
        agents:"## Project notes") old_notes="$buf" ;;
        constitution:"## 3. Protected surfaces") old_protected=$(printf '%s' "$buf" | grep -oE '`[^`]+`' | tr -d '`' | tr '\n' ' ') ;;
        constitution:"## 4. Stack & architecture") old_constraints="$buf" ;;
        *) { echo; echo "## $f — $h"; echo; echo '```'; printf '%s\n' "$buf"; echo '```'; } >> "$report" ;;
      esac
    }
    while IFS= read -r line; do
      case "$line" in "@@ "*) flush; seen=yes; h="${line#@@ }"; buf="" ;; *) buf="$buf$line"$'\n' ;; esac
    done < <(slots "$f")
    flush
  }
  harvest AGENTS.md agents
  harvest CONSTITUTION.md constitution
  harvest .github/workflows/ci.yml ci
  harvest .github/workflows/review-gate.yml ci
  jq -r '.files | keys[]' .template-manifest.json | while IFS= read -r p; do
    [ "$p" = .gitignore ] && continue
    [ -e "$p" ] || [ -L "$p" ] || continue
    rm -rf "$p"
  done
  [ -f .gitignore ] && { grep -vE '^[[:space:]]*#?[[:space:]]*<!-- /?local -->[[:space:]]*$' .gitignore > .gitignore.new; mv .gitignore.new .gitignore; }
  rm -rf .t-workflow migrations .template-manifest.json .github/ISSUE_TEMPLATE docs/adapters docs/architecture docs/workflow.md
  find docs/adr -maxdepth 1 -name '0[0-9][0-9]-*.md' -delete 2>/dev/null || true
  find docs .github .claude -type d -empty -delete 2>/dev/null || true
  note "removed the old t-workflow's files"
fi

# --- copy the owned set ------------------------------------------------------------
for p in $OWNED; do
  rm -rf "$p"; mkdir -p "$(dirname "$p")"; cp -R "$src/$p" "$p"
done
printf '%s\n' "$tag" > .t-workflow/VERSION
chmod +x .t-workflow/scripts/*.sh
mkdir -p .agents docs/tasks
[ -e .agents/skills ] || ln -s ../.claude/skills .agents/skills
[ -n "$report" ] && mv "$report" .t-workflow/REPLACED.md
note "installed the owned set"

# --- consumer-owned files, created only when absent --------------------------------
detect_check() {
  if [ -f package.json ]; then echo "npm test"
  elif [ -f Gemfile ]; then { [ -d spec ] && echo "bundle exec rspec"; } || echo "bundle exec rake test"
  elif [ -f Cargo.toml ]; then echo "cargo test"
  elif [ -f go.mod ]; then echo "go test ./..."
  elif [ -f pyproject.toml ] || [ -f pytest.ini ] || [ -f setup.py ]; then echo "pytest"
  elif [ -f mix.exs ]; then echo "mix test"
  elif [ -f build.gradle ] || [ -f build.gradle.kts ]; then echo "./gradlew test"
  elif [ -f pom.xml ]; then echo "mvn test"
  elif [ -f Makefile ] && grep -qE '^test:' Makefile; then echo "make test"
  fi
}
default_config() {
  cat <<'CONFIG'
# t-workflow configuration. Owned by this repository; never touched by an update.
# Shell syntax: key="value". Read by .t-workflow/scripts/*.

# Build/test command, run as check 1 (empty = no check 1 yet).
check=""

# Extra protected globs, space-separated, on top of the built-in set
# (e.g. "db/migrate/* config/*"). A protected diff needs a plan and a cold review.
protected=""

# Extra documentation globs, space-separated, on top of *.md and docs/*
# (e.g. "site/*"). A documentation-only diff skips check 1.
docs=""

# Branch globs exempt from the task gates in CI (e.g. "dependabot/*"). Check 1 still runs.
exempt=""

# Model /t-review's subagent reviewer runs under (empty = the invoking session's own).
reviewer_model=""
CONFIG
}
if [ ! -f .t-workflow/config ]; then
  default_config > .t-workflow/config
  chk="${check_arg:-${old_check:-$(detect_check)}}"
  [ -n "$chk" ] && sed -i.bak "s|^check=\"\"|check=\"$(printf '%s' "$chk" | sed 's/[|&\\]/\\&/g')\"|" .t-workflow/config
  [ -n "${old_protected:-}" ] && sed -i.bak "s|^protected=\"\"|protected=\"${old_protected% }\"|" .t-workflow/config
  [ -n "${old_docs:-}" ] && sed -i.bak "s|^docs=\"\"|docs=\"${old_docs% }\"|" .t-workflow/config
  [ -n "${old_model:-}" ] && sed -i.bak "s|^reviewer_model=\"\"|reviewer_model=\"$old_model\"|" .t-workflow/config
  rm -f .t-workflow/config.bak
  note "wrote .t-workflow/config (check: ${chk:-none detected})"
else
  # A release may add a key: append what this config lacks, with its comment, leaving present values alone.
  def=$(mktemp); default_config > "$def"
  [ -z "$(tail -c1 .t-workflow/config)" ] || echo >> .t-workflow/config   # end with a newline before appending
  for key in $(grep -oE '^[a-z_]+=' "$def" | tr -d =); do
    grep -q "^$key=" .t-workflow/config && continue
    awk -v k="$key=" '/^#/{b=b $0 "\n"; next} index($0,k)==1{printf "\n%s%s\n", b, $0; exit} {b=""}' "$def" >> .t-workflow/config
    note "config: added $key with its default"
  done
  rm -f "$def"
  if [ -n "$check_arg" ]; then
    sed -i.bak "s|^check=.*|check=\"$(printf '%s' "$check_arg" | sed 's/[|&\\]/\\&/g')\"|" .t-workflow/config; rm -f .t-workflow/config.bak
  fi
fi

pointer='Read `.t-workflow/AGENTS.md` first — the delivery workflow for this repository.'
if [ ! -e AGENTS.md ] && [ -f CLAUDE.md ] && [ ! -L CLAUDE.md ]; then mv CLAUDE.md AGENTS.md; fi
if [ -L AGENTS.md ] && [ ! -e AGENTS.md ]; then rm -f AGENTS.md; fi
if [ ! -e AGENTS.md ]; then
  { echo "$pointer"; echo; echo "## Project notes"; echo
    if [ -n "${old_notes:-}" ]; then printf '%s\n' "$old_notes"; else echo "*(this repository's own session-start instructions)*"; fi
    [ -n "${old_constraints:-}" ] && { echo; echo "## Constraints"; echo; printf '%s\n' "$old_constraints"; }
  } > AGENTS.md
elif ! grep -qF '.t-workflow/AGENTS.md' AGENTS.md; then
  { echo "$pointer"; echo; cat AGENTS.md; } > AGENTS.md.new && mv AGENTS.md.new AGENTS.md
fi
for alias in CLAUDE.md GEMINI.md; do [ -e "$alias" ] || [ -L "$alias" ] || ln -s AGENTS.md "$alias"; done

# --- --no-pr stops here -------------------------------------------------------------
if [ "$pr" = no ]; then
  note "done (no PR): review the changes with git status / git diff"
  exit 0
fi

# --- record, commit, PR, protection ------------------------------------------------
rec=$(.t-workflow/scripts/record.sh create "$id")
git add -A
git commit -q -m "$title" -m "Task: #$id — $rec"
git push -q -u origin "$branch"
prbody=$(mktemp)
{
  echo "Closes #$id"; echo
  echo "$title. Every t-workflow-owned file is the release's copy; \`.t-workflow/config\` and \`AGENTS.md\` are this repository's own."
  [ "$mode" = replace ] && echo "Old local-slot content with no automatic home is in \`.t-workflow/REPLACED.md\`."
  echo; echo "## Checks run"; echo "- \`.t-workflow/scripts/ci.sh\` — runs on this PR"
} > "$prbody"
if [ "$mode" = update ]; then
  prurl=$(gh pr create --draft --title "[$id] $title" --body-file "$prbody")
else
  prurl=$(gh pr create --title "[$id] $title" --body-file "$prbody")
fi
rm -f "$prbody"
if [ "$protect" = yes ] && [ "$mode" != update ]; then .t-workflow/scripts/protect.sh || true; fi
note ""
note "PR: $prurl"
case "$mode" in
  update) note "next: /t-drive $id (cold review, then the merge question)" ;;
  *) note "next: review the PR and merge it; the workflow is in force from then on" ;;
esac
