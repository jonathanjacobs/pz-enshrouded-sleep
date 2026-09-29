#!/usr/bin/env bash
# Check that every tracked Lua file parses as Lua 5.1, the language Project
# Zomboid's Kahlua interpreter reads. This catches a syntax error in seconds,
# before a server has to start and a client join to show it.
#
# Run from anywhere:  bash tools/check-lua-syntax.sh [--require-compiler]
# CI runs it from .github/workflows/validate-package.yml with --require-compiler.
#
# A file that parses can still fail at runtime: this proves only that the
# syntax is valid Lua 5.1. Without a Lua 5.1 compiler (luac5.1, or a luac that
# reports version 5.1) the script says the check was skipped and exits 0,
# unless --require-compiler is given.

set -uo pipefail

cd "$(git -C "$(dirname "$0")" rev-parse --show-toplevel)" || exit 2

require_compiler=0
[[ "${1:-}" == "--require-compiler" ]] && require_compiler=1

summary() {
  echo "$1"
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    { echo "## Lua syntax"; echo; echo "$1"; } >>"$GITHUB_STEP_SUMMARY"
  fi
}

luac=""
for candidate in luac5.1 luac; do
  if command -v "$candidate" >/dev/null 2>&1 && "$candidate" -v 2>&1 | grep -q 'Lua 5\.1'; then
    luac="$candidate"
    break
  fi
done

mapfile -t files < <(git ls-files '*.lua')

if ((${#files[@]} == 0)); then
  summary "Skipped: no tracked Lua files."
  exit 0
fi

if [[ -z "$luac" ]]; then
  if ((require_compiler)); then
    summary "Failed: no Lua 5.1 compiler (luac5.1) is installed, so ${#files[@]} Lua file(s) were not checked."
    exit 1
  fi
  summary "Skipped: no Lua 5.1 compiler (luac5.1) is installed, so ${#files[@]} Lua file(s) were not checked. CI still runs this check."
  exit 0
fi

failed=0
for file in "${files[@]}"; do
  if ! output="$("$luac" -p -- "$file" 2>&1)"; then
    echo "$output"
    failed=$((failed + 1))
  fi
done

if ((failed > 0)); then
  summary "Failed: ${failed} of ${#files[@]} Lua file(s) do not parse as Lua 5.1."
  exit 1
fi
summary "Checked: ${#files[@]} Lua file(s) parse as Lua 5.1. Parsing does not show that the code runs correctly."
