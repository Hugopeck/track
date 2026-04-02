#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK="$SCRIPT_DIR/../skills/setup-track/assets/hooks/pre-push"
MANIFEST_FILE="$SCRIPT_DIR/../skills/setup-track/assets/install-manifest.json"
PASS=0
FAIL=0

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

setup_git_repo() {
  local repo
  repo="$(mktemp -d)"
  git init -q "$repo"
  git -C "$repo" config user.name 'Track Test'
  git -C "$repo" config user.email 'track-test@example.com'
  printf '%s' "$repo"
}

write_validate_script() {
  local repo="$1"
  local script_path="$2"
  local exit_code="$3"
  mkdir -p "$(dirname "$repo/$script_path")"
  cat > "$repo/$script_path" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$script_path" > "$repo/.validate-ran"
exit $exit_code
EOF
  chmod +x "$repo/$script_path"
}

run_hook() {
  local repo="$1"
  local exit_code=0
  (cd "$repo" && bash "$HOOK") >/dev/null 2>&1 || exit_code=$?
  return "$exit_code"
}

printf 'Running pre-push hook tests...\n\n'

printf '── Hook file ──\n'

if [[ -x "$HOOK" ]]; then
  pass 'pre-push hook is executable'
else
  fail 'pre-push hook is executable'
fi

if [[ "$(head -1 "$HOOK")" == '#!/usr/bin/env bash' ]]; then
  pass 'pre-push hook has bash shebang'
else
  fail 'pre-push hook has bash shebang'
fi

printf '\n── Validation behavior ──\n'

repo="$(setup_git_repo)"
write_validate_script "$repo" '.track/scripts/track-validate.sh' 0
if run_hook "$repo" && [[ "$(cat "$repo/.validate-ran")" == '.track/scripts/track-validate.sh' ]]; then
  pass 'hook runs installed Track validator'
else
  fail 'hook runs installed Track validator'
fi
rm -rf "$repo"

repo="$(setup_git_repo)"
write_validate_script "$repo" '.track/scripts/track-validate.sh' 1
if run_hook "$repo"; then
  fail 'hook blocks push on validation failure'
else
  pass 'hook blocks push on validation failure'
fi
rm -rf "$repo"

repo="$(setup_git_repo)"
write_validate_script "$repo" 'scripts/validate/track-validate.sh' 0
if run_hook "$repo" && [[ "$(cat "$repo/.validate-ran")" == 'scripts/validate/track-validate.sh' ]]; then
  pass 'hook falls back to source-repo validator path'
else
  fail 'hook falls back to source-repo validator path'
fi
rm -rf "$repo"

repo="$(setup_git_repo)"
if run_hook "$repo"; then
  fail 'hook fails when no validator is installed'
else
  pass 'hook fails when no validator is installed'
fi
rm -rf "$repo"

printf '\n── Manifest wiring ──\n'

if grep -Fq 'skills/setup-track/assets/hooks/pre-push' "$MANIFEST_FILE"; then
  pass 'manifest installs pre-push hook asset'
else
  fail 'manifest installs pre-push hook asset'
fi

if grep -Fq '.git/hooks/pre-push' "$MANIFEST_FILE"; then
  pass 'manifest installs pre-push hook destination'
else
  fail 'manifest installs pre-push hook destination'
fi

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
