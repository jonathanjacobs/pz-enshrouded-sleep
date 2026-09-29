#!/usr/bin/env bash
# Check for private server, player, and credential details before they reach
# GitHub. docs/PRIVATE_DATA.md explains the rules and what to do after a leak.
#
# The same script runs in three places, so the patterns are defined only here:
#
#   bash tools/check-sensitive-content.sh staged       Before a commit (the Git
#                                                      hook in .githooks/). Checks
#                                                      only the files being
#                                                      committed.
#   bash tools/check-sensitive-content.sh tracked      In CI, on every tracked
#                                                      file. This is the default.
#   bash tools/check-sensitive-content.sh text LABEL   In CI, on text read from
#                                                      standard input, such as a
#                                                      pull request description.
#
# Any finding makes the script exit non-zero. To accept one line that is a
# false positive, such as a four-part version number, add the marker
# "sensitive-content: allow" to that line.
#
# Project patterns (player names, server host names) are regular expressions,
# one per line. CI reads them from the SENSITIVE_PATTERNS repository secret.
# On a computer, keep them in a file outside the repository and run once:
#   git config --global pzmod.sensitivePatternsFile /path/to/patterns.txt
#
# Requires bash and Git built with PCRE support (Git for Windows and the CI
# runner both are).

set -uo pipefail

readonly ALLOW_MARKER='sensitive-content: allow'

# Files that hold real local values or private keys. A name ending in .example
# is allowed: it holds placeholders meant to be shared.
readonly SECRET_FILE_PATTERN='(^|/)(\.env($|\.)|[^/]+\.env$|id_(rsa|dsa|ecdsa|ed25519)$|[^/]+\.(pem|ppk)$)'

# Perl-compatible patterns for private values inside files and text. Each entry
# is "label|regex"; the label is what a finding reports.
readonly BUILTIN_PATTERNS=(
  # Any IPv4 address except loopback, 0.0.0.0, broadcast, and the three ranges
  # reserved for documentation (192.0.2.x, 198.51.100.x, 203.0.113.x).
  'IP address|(?<![\w.])(?!(?:127\.|0\.0\.0\.0|255\.255\.255\.255|192\.0\.2\.|198\.51\.100\.|203\.0\.113\.))(?:(?:25[0-5]|2[0-4]\d|1?\d?\d)\.){3}(?:25[0-5]|2[0-4]\d|1?\d?\d)(?!\.?\d)'
  # SteamID64 values all start with 7656119 and have 17 digits.
  'Steam ID|(?<!\d)7656119\d{10}(?!\d)'
  # Project Zomboid server settings files (<servername>.ini).
  'server password setting|^\s*(?:Password|RCONPassword)\s*=\s*\S'
  # KEY=value settings such as SFTP_PASSWORD=..., skipping empty values and
  # <placeholder> values.
  'password or token setting|^\s*(?:export\s+)?[A-Z0-9_]*(?:PASSWORD|PASSWD|TOKEN|SECRET|API_KEY)[A-Z0-9_]*\s*=\s*(?![<#\s]|""|'"''"'|$)\S'
  # A user name and password or token written into a URL.
  'credentials in a URL|[a-z][a-z0-9+.-]*://[^/\s:@]+:[^/\s@]+@'
  # GitHub personal access tokens.
  'GitHub token|(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,}'
)

in_github_actions() {
  [[ "${GITHUB_ACTIONS:-}" == "true" ]]
}

# Print one finding. In GitHub Actions the matched text is left out, because
# the workflow log is public for a public repository.
report() {
  local location="$1" message="$2" detail="${3:-}"
  if in_github_actions; then
    local file="${location%%:*}" line=""
    [[ "$location" == *:* ]] && line=",line=${location#*:}"
    if [[ -n "$file" ]]; then
      echo "::error file=${file}${line}::${message}"
    else
      echo "::error::${message}"
    fi
  else
    echo "${location:+${location}: }${message}${detail:+ -> ${detail}}" >&2
  fi
  findings=$((findings + 1))
}

load_patterns() {
  patterns=("${BUILTIN_PATTERNS[@]}")
  local project_patterns="${SENSITIVE_PATTERNS:-}" patterns_file pattern
  patterns_file="$(git config --get pzmod.sensitivePatternsFile || true)"
  if [[ -n "$patterns_file" && -r "$patterns_file" ]]; then
    project_patterns+=$'\n'"$(tr -d '\r' <"$patterns_file")"
  fi
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] && patterns+=("project pattern|${pattern}")
  done <<<"$project_patterns"
}

# Argument: "staged" or "tracked".
check_file_names() {
  local mode="$1" names file
  if [[ "$mode" == "staged" ]]; then
    names="$(git diff --cached --name-only --diff-filter=ACMR)"
  else
    names="$(git ls-files)"
  fi
  while IFS= read -r file; do
    [[ -n "$file" ]] && report "$file" "This file holds local secrets or a private key and must not be committed."
  done < <(grep -E "$SECRET_FILE_PATTERN" <<<"$names" | grep -vE '\.example$' || true)
}

# Argument: "staged" or "tracked".
check_file_contents() {
  local mode="$1" entry label regex file line_number detail
  local grep_args=(-nIP) paths=(.)
  if [[ "$mode" == "staged" ]]; then
    grep_args+=(--cached)
    mapfile -t paths < <(git diff --cached --name-only --diff-filter=ACMR)
    ((${#paths[@]} == 0)) && return
  fi
  for entry in "${patterns[@]}"; do
    label="${entry%%|*}"
    regex="${entry#*|}"
    while IFS=: read -r file line_number detail; do
      [[ "$detail" == *"$ALLOW_MARKER"* ]] && continue
      report "${file}:${line_number}" "Possible ${label}." "$detail"
    done < <(git grep "${grep_args[@]}" -e "$regex" -- "${paths[@]}" | tr -d '\r' || true)
  done
}

# Argument: a label naming the text. Reads the text from standard input.
check_text() {
  local label="$1" text entry line
  text="$(tr -d '\r')"
  for entry in "${patterns[@]}"; do
    while IFS= read -r line; do
      [[ "$line" == *"$ALLOW_MARKER"* ]] && continue
      report "" "Possible ${entry%%|*} in ${label}." "$line"
    done < <(grep -P -e "${entry#*|}" <<<"$text" || true)
  done
}

summarize() {
  ((findings == 0)) && return
  if in_github_actions; then
    [[ -n "${GITHUB_STEP_SUMMARY:-}" ]] || return
    {
      echo "### Possible private details found"
      echo
      echo "${findings} finding(s). The log gives each location without repeating the matched text."
      echo "Remove each value, or describe the server by its kind, such as \"a rented dedicated server\"."
      echo "Anything already pushed stays in Git history and on GitHub: follow 'If private details reach GitHub' in docs/PRIVATE_DATA.md."
      echo "For a false positive, add the marker 'sensitive-content: allow' to that line."
    } >>"$GITHUB_STEP_SUMMARY"
  else
    {
      echo
      echo "${findings} possible private detail(s) found. docs/PRIVATE_DATA.md explains what to do:"
      echo "- Remove the value, or describe the server by its kind, such as \"a rented dedicated server\"."
      echo "- Keep real settings in an ignored file and commit a placeholder copy whose name ends in .example."
      echo "- For a false positive, add the marker 'sensitive-content: allow' to that line."
    } >&2
  fi
}

main() {
  local mode="${1:-tracked}"
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "Run this script inside a Git repository." >&2
    return 2
  fi
  cd "$(git rev-parse --show-toplevel)" || return 2
  load_patterns
  findings=0
  case "$mode" in
    staged | tracked)
      check_file_names "$mode"
      check_file_contents "$mode"
      ;;
    text)
      check_text "${2:-the text}"
      ;;
    *)
      echo "Usage: $0 [staged | tracked | text LABEL]" >&2
      return 2
      ;;
  esac
  summarize
  ((findings == 0))
}

main "$@"
