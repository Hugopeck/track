#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/fixtures"
SCAFFOLD_SCRIPTS="$SCRIPT_DIR/../skills/init/scaffold/track/scripts"
PASS=0
FAIL=0

pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
}

assert_contains() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -Fq -- "$pattern" "$file"; then
    pass "$name"
  else
    fail "$name"
    printf '    missing pattern %q in %s\n' "$pattern" "$file"
  fi
}

assert_not_contains() {
  local name="$1"
  local pattern="$2"
  local file="$3"
  if grep -Fq -- "$pattern" "$file"; then
    fail "$name"
    printf '    unexpected pattern %q in %s\n' "$pattern" "$file"
  else
    pass "$name"
  fi
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d)"
  cp -r "$FIXTURE_DIR/.track" "$tmp/.track"
  mkdir -p "$tmp/.track/scripts"
  cp "$SCAFFOLD_SCRIPTS"/track-common.sh "$tmp/.track/scripts/"
  cp "$SCAFFOLD_SCRIPTS"/track-todo.sh "$tmp/.track/scripts/"
  printf '%s' "$tmp"
}

setup_gh_mock() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/gh" <<'GH'
#!/usr/bin/env bash
set -euo pipefail

if [[ "$1 $2" == 'pr list' ]]; then
  if [[ "$*" == *'--json number,url,isDraft,headRefName,title'* ]]; then
    printf '%s\t%s\t%s\t%s\t%s\n' 101 'https://example.com/pr/101' true 'task/1.1-test-task' '[1.1] Draft PR'
    printf '%s\t%s\t%s\t%s\t%s\n' 102 'https://example.com/pr/102' false 'feature/label-single' 'Ready single'
    printf '%s\t%s\t%s\t%s\t%s\n' 103 'https://example.com/pr/103' false 'task/1.3-dependent-task' '[1.3] Duplicate branch PR'
    exit 0
  fi
fi

if [[ "$1 $2" == 'pr view' ]]; then
  pr_number="$3"
  case "$pr_number" in
    101)
      if [[ "$*" == *'--json body'* ]]; then
        printf 'Track-Task: 1.1\n'
      else
        printf ''
      fi
      ;;
    102)
      if [[ "$*" == *'--json body'* ]]; then
        printf ''
      else
        printf 'track:1.3'
      fi
      ;;
    103)
      if [[ "$*" == *'--json body'* ]]; then
        printf ''
      else
        printf ''
      fi
      ;;
  esac
  exit 0
fi

echo "unexpected gh invocation: $*" >&2
exit 1
GH
  chmod +x "$dir/gh"
}

printf 'Running extended todo tests...\n\n'

repo="$(setup_repo)"
mock_bin="$(mktemp -d)"
setup_gh_mock "$mock_bin"
PATH="$mock_bin:$PATH" bash "$repo/.track/scripts/track-todo.sh" --local --output "$repo/TODO.md" >/dev/null

assert_contains 'task from body shows active with PR link' '| [1.1](.track/tasks/1.1-test-task.md) | [Test task](.track/tasks/1.1-test-task.md) | implement | medium | — | active · [PR](https://example.com/pr/101) |' "$repo/TODO.md"
assert_contains 'same task linked by two distinct PRs warns' "multiple open PRs map to task '1.3'" "$repo/TODO.md"
assert_not_contains 'single-task PR does not warn for 1.1' "multiple open PRs map to task '1.1'" "$repo/TODO.md"

rm -rf "$repo" "$mock_bin"

printf '\nSummary: %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ $FAIL -ne 0 ]]; then
  exit 1
fi
