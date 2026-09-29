#!/usr/bin/env bash
# Package validation for a Project Zomboid Build 42 mod repository.
#
# Run from anywhere:  bash tools/validate-package.sh [repository-root]
# CI runs the same script from .github/workflows/validate-package.yml.
#
# Checks fall into two tiers:
#   - always: package layout, mod.info identity/version, version drift across
#     README / Workshop text / runtime Lua, sandbox-option translations,
#     package hygiene, the docs/README.md index (warnings only), and artwork
#     dimensions for artwork that exists;
#   - once publishing (workshop.txt has a numeric id=): required artwork and
#     no leftover [PLACEHOLDER] text in the Workshop description.
#
# Add project-specific regression guards in the marked section near the end.
# Each guard should protect against a defect or design choice that has
# already happened once, not against hypothetical problems.
#
# Requires only bash, grep, sed, od, and stat, so it runs in Git Bash on
# Windows as well as on the CI runner.

set -uo pipefail

cd "${1:-$(dirname "$0")/..}" || exit 2

errors=0
warnings=0
fail() { echo "ERROR: $*"; errors=$((errors + 1)); }
warn() { echo "WARNING: $*"; warnings=$((warnings + 1)); }

# Read a file with Windows line endings removed.
text() { tr -d '\r' < "$1"; }

# ---------------------------------------------------------------------------
# Identity
# ---------------------------------------------------------------------------

VERSION_VALUE="$(tr -d '\r\n' < VERSION 2>/dev/null || true)"
if [[ ! "$VERSION_VALUE" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  fail "VERSION must hold a single x.y.z version (found '$VERSION_VALUE')"
fi

mapfile -t mod_dirs < <(find Contents/mods -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
if [[ "${#mod_dirs[@]}" -ne 1 ]]; then
  fail "expected exactly one mod directory under Contents/mods/ (found ${#mod_dirs[@]})"
  echo "Validation stopped: package root is ambiguous."
  exit 1
fi
MOD_ROOT="${mod_dirs[0]}"
MOD_ID="$(basename "$MOD_ROOT")"
RUNTIME_LUA="$MOD_ROOT/42/media/lua"

if [[ "$MOD_ID" == "pz-mod-id" ]]; then
  warn "mod ID is still the template placeholder 'pz-mod-id'"
fi

PUBLISHING=0
WORKSHOP_ID=""
if [[ -f workshop.txt ]]; then
  WORKSHOP_ID="$(text workshop.txt | sed -n 's/^id=\([0-9][0-9]*\)$/\1/p')"
  [[ -n "$WORKSHOP_ID" ]] && PUBLISHING=1
fi

# Apache 2.0 section 4(d) requires the template's NOTICE attribution to be
# carried in redistributions. Warn only: this is a reminder, not a gate.
if [[ ! -f NOTICE ]]; then
  warn "NOTICE is missing; it must carry the pz-mod-template attribution block"
elif ! text NOTICE | grep -Fq "Copyright 2026 Jonathan Jacobs" \
     || ! text NOTICE | grep -Fq "github.com/jonathanjacobs/pz-mod-template"; then
  warn "NOTICE no longer carries the pz-mod-template attribution block (see CREDITS.md)"
fi

# ---------------------------------------------------------------------------
# Layout: one authoritative runtime tree
# ---------------------------------------------------------------------------

for stray in 42 common media mod.info; do
  [[ -e "$stray" ]] && fail "stray root-level '$stray' — the only runtime tree is $MOD_ROOT/"
done
[[ -d "$MOD_ROOT/common" ]] || fail "$MOD_ROOT/common/ is missing (Build 42 expects it beside 42/)"
[[ -d "$MOD_ROOT/42" ]] || fail "$MOD_ROOT/42/ is missing"

# ---------------------------------------------------------------------------
# mod.info
# ---------------------------------------------------------------------------

for info in "$MOD_ROOT/mod.info" "$MOD_ROOT/42/mod.info"; do
  if [[ ! -f "$info" ]]; then
    fail "$info is missing"
    continue
  fi
  text "$info" | grep -Fxq "id=$MOD_ID" || fail "$info: expected 'id=$MOD_ID' to match the folder name"
  text "$info" | grep -Fxq "modversion=$VERSION_VALUE" || fail "$info: expected 'modversion=$VERSION_VALUE' to match VERSION"
  text "$info" | grep -q '^version=' && fail "$info: uses 'version='; Build 42 mod.info uses 'modversion='"
  text "$info" | grep -q '=TBD' && warn "$info: still contains TBD values"
done

if [[ -f "$MOD_ROOT/42/mod.info" ]] && ! text "$MOD_ROOT/42/mod.info" | grep -q '^versionMin='; then
  fail "$MOD_ROOT/42/mod.info: missing 'versionMin=' (the oldest tested Project Zomboid build)"
fi

# Artwork referenced by 42/mod.info must exist once the mod is being published.
if [[ -f "$MOD_ROOT/42/mod.info" ]]; then
  for key in poster icon; do
    ref="$(text "$MOD_ROOT/42/mod.info" | sed -n "s/^$key=//p")"
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$MOD_ROOT/42/$ref" ]]; then
      if [[ "$PUBLISHING" -eq 1 ]]; then
        fail "42/mod.info references $key=$ref but $MOD_ROOT/42/$ref does not exist"
      else
        warn "42/mod.info references $key=$ref but the file does not exist yet (required before publishing)"
      fi
    fi
  done
fi

# ---------------------------------------------------------------------------
# Version drift across public text and runtime Lua
# ---------------------------------------------------------------------------

# Every bold version label in README.md (for example **v1.2.3**) must match.
while read -r label; do
  [[ "$label" == "v$VERSION_VALUE" ]] || fail "README.md shows version $label (expected v$VERSION_VALUE)"
done < <(grep -oE '\*\*v[0-9]+\.[0-9]+\.[0-9]+\*\*' README.md 2>/dev/null | tr -d '*' | sort -u)

BBCODE="docs/workshop-description.bbcode"
# Template 0.6.0 moved the description from the repository root into docs/.
if [[ -f workshop-description.bbcode ]]; then
  warn "workshop-description.bbcode is at the repository root; move it to $BBCODE, where these checks look for it"
fi
if [[ -f "$BBCODE" ]]; then
  bb_version="$(text "$BBCODE" | sed -n 's/^\[b\]Version:\[\/b\] *//p' | head -1)"
  if [[ -n "$bb_version" && "$bb_version" != "[VERSION]" && "$bb_version" != "$VERSION_VALUE" ]]; then
    fail "$BBCODE shows Version: $bb_version (expected $VERSION_VALUE)"
  fi
  # Steam does not render these tags; they show up as literal text.
  if grep -nE '\[/?(center|br)\]' "$BBCODE"; then
    fail "$BBCODE uses [center] or [br], which Steam does not render"
  fi
  if [[ "$PUBLISHING" -eq 1 ]] && grep -nE '[[A-Z][A-Z0-9_ ]{2,}]' "$BBCODE"; then
    fail "$BBCODE still contains [PLACEHOLDER] text"
  fi
fi

if [[ -f workshop.txt ]]; then
  while read -r label; do
    [[ "$label" == "v$VERSION_VALUE" ]] || fail "workshop.txt description shows $label (expected v$VERSION_VALUE)"
  done < <(text workshop.txt | sed -n 's/^description=//p' | grep -oE '\bv[0-9]+\.[0-9]+\.[0-9]+\b' | sort -u)
fi

# Runtime build stamps (see docs/DESIGN.md): BUILD_VERSION = "x.y.z",
# buildVersion = "x.y.z", and "Loaded vx.y.z" load banners must match VERSION.
if [[ -d "$RUNTIME_LUA" ]]; then
  while read -r stamp; do
    [[ "$stamp" == "$VERSION_VALUE" ]] || fail "runtime Lua build stamp \"$stamp\" does not match VERSION $VERSION_VALUE"
  done < <(grep -RhoE '(BUILD_VERSION|buildVersion)[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$RUNTIME_LUA" 2>/dev/null \
             | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -u)
  while read -r stamp; do
    [[ "$stamp" == "v$VERSION_VALUE" ]] || fail "runtime Lua load banner shows $stamp (expected v$VERSION_VALUE)"
  done < <(grep -RhoE 'Loaded v[0-9]+\.[0-9]+\.[0-9]+' "$RUNTIME_LUA" 2>/dev/null | sed 's/^Loaded //' | sort -u)
fi

# ---------------------------------------------------------------------------
# Sandbox options: every option binds a translated label
# ---------------------------------------------------------------------------

SANDBOX_OPTIONS="$MOD_ROOT/42/media/sandbox-options.txt"
TRANSLATE_EN="$MOD_ROOT/42/media/lua/shared/Translate/EN"
if [[ -f "$SANDBOX_OPTIONS" ]]; then
  # Emit "option-name translation-key" per option block ('-' if no translation line).
  mapfile -t option_rows < <(text "$SANDBOX_OPTIONS" | awk '
    /^[[:space:]]*option[[:space:]]+/ { if (name != "") print name, (tr == "" ? "-" : tr); name = $2; sub(/[={].*$/, "", name); tr = ""; next }
    /^[[:space:]]*translation[[:space:]]*=/ { tr = $0; sub(/^[^=]*=[[:space:]]*/, "", tr); sub(/[[:space:],]*$/, "", tr) }
    END { if (name != "") print name, (tr == "" ? "-" : tr) }')
  for row in "${option_rows[@]}"; do
    name="${row%% *}"
    key="${row#* }"
    if [[ "$key" == "-" ]]; then
      fail "sandbox option $name has no 'translation =' line"
      continue
    fi
    if ! grep -RqsF "Sandbox_$key\"" "$TRANSLATE_EN" && ! grep -RqsE "Sandbox_$key[[:space:]]*=" "$TRANSLATE_EN"; then
      fail "sandbox option $name: no EN translation for Sandbox_$key under $TRANSLATE_EN/"
    fi
  done
  while read -r page; do
    if ! grep -RqsF "Sandbox_$page\"" "$TRANSLATE_EN" && ! grep -RqsE "Sandbox_$page[[:space:]]*=" "$TRANSLATE_EN"; then
      fail "sandbox page '$page' has no EN translation for Sandbox_$page"
    fi
  done < <(text "$SANDBOX_OPTIONS" | sed -n 's/^[[:space:]]*page[[:space:]]*=[[:space:]]*\([A-Za-z0-9_]*\).*/\1/p' | sort -u)
fi

# ---------------------------------------------------------------------------
# Package hygiene
# ---------------------------------------------------------------------------

while read -r bad; do
  fail "non-runtime file in the package: $bad"
done < <(find "$MOD_ROOT" -type f \( -name '*.log' -o -name '*.bak' -o -name '*.tmp' -o -name '*.zip' -o -name '*.7z' \
           -o -name '.env*' -o -name 'server-console*.txt' -o -path '*/DebugLog*' -o -name '*.java' -o -name '*.class' \) 2>/dev/null)

# ---------------------------------------------------------------------------
# Documentation index
# ---------------------------------------------------------------------------

# docs/README.md lists every file and folder in docs/, and AGENTS.md asks for it
# to be updated with each addition, removal, or rename. Warn only.
if [[ -f docs/README.md ]]; then
  docs_index="$(text docs/README.md)"
  for entry in docs/*; do
    name="$(basename "$entry")"
    [[ "$name" == "README.md" ]] && continue
    [[ -d "$entry" ]] && name="$name/"
    grep -Fq "]($name" <<<"$docs_index" || warn "docs/README.md does not list docs/$name"
  done
  while read -r target; do
    [[ -e "docs/$target" ]] || warn "docs/README.md links to $target, which does not exist"
  done < <(grep -oE '\]\([^)#:]+' <<<"$docs_index" | sed 's/^](//')
fi

# ---------------------------------------------------------------------------
# Artwork
# ---------------------------------------------------------------------------

# png_size FILE -> prints "WIDTH HEIGHT", or nothing if FILE is not a PNG.
png_size() {
  local sig
  sig="$(od -An -tx1 -N8 "$1" | tr -d ' \n')"
  [[ "$sig" == "89504e470d0a1a0a" ]] || return 0
  od -An -tu1 -j16 -N8 "$1" | awk '{ printf "%d %d\n", $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8 }'
}

check_png() { # FILE REQUIRED(0|1) [WIDTH HEIGHT]
  local file="$1" required="$2" want_w="${3:-}" want_h="${4:-}" size
  if [[ ! -f "$file" ]]; then
    [[ "$required" -eq 1 ]] && fail "$file is required before publishing"
    return
  fi
  size="$(png_size "$file")"
  if [[ -z "$size" ]]; then
    fail "$file is not a PNG"
    return
  fi
  if [[ -n "$want_w" && "$size" != "$want_w $want_h" ]]; then
    fail "$file is ${size/ /x}; expected ${want_w}x${want_h}"
  fi
}

# The Project Zomboid Workshop uploader expects a 256x256 preview under Steam's 1 MB limit.
check_png preview.png "$PUBLISHING" 256 256
if [[ -f preview.png ]] && (( $(stat -c %s preview.png 2>/dev/null || wc -c < preview.png) > 1024000 )); then
  fail "preview.png exceeds 1000 KB"
fi
# Poster and icon dimensions are not enforced; only their PNG identity is.
[[ -f "$MOD_ROOT/42/poster.png" ]] && check_png "$MOD_ROOT/42/poster.png" 0
[[ -f "$MOD_ROOT/42/icon.png" ]] && check_png "$MOD_ROOT/42/icon.png" 0

# ---------------------------------------------------------------------------
# Project-specific regression guards
# ---------------------------------------------------------------------------
# Turn each regression that has actually happened into a guard here, with a
# comment saying what it protects. Examples from earlier Build 42 mods:
#
# Reject dynamic-code APIs (Project Zomboid 42.20.4 removed loadstring and
# loadstream; 42.21.0 restored them):
#   if [[ -d "$RUNTIME_LUA" ]] && grep -RnE '(^|[^[:alnum:]_])(loadstring|loadstream)([^[:alnum:]_]|$)' "$RUNTIME_LUA"; then
#     fail "dynamic-code API referenced by runtime Lua"
#   fi
#
# Keep a server-authoritative path off the client:
#   if grep -Fq "addXpNoMultiplier" "$RUNTIME_LUA/client/<Mod>/Feature_Client.lua"; then
#     fail "client-authoritative XP path reintroduced"
#   fi
#
# Keep a pre-release label from returning after a stable release:
#   if grep -RIni 'release candidate' "$MOD_ROOT" README.md workshop.txt "$BBCODE"; then
#     fail "pre-release label found in package or public text"
#   fi

# Through v1.0.1 the root mod.info carried pzversion=42 and lacked the
# category= and versionMin= values in 42/mod.info. Both files carry the same
# shared values (see "Runtime layout" in docs/DESIGN.md).
if [[ -f "$MOD_ROOT/mod.info" && -f "$MOD_ROOT/42/mod.info" ]]; then
  for key in id name description author category modversion versionMin; do
    root_value="$(text "$MOD_ROOT/mod.info" | sed -n "s/^$key=//p" | head -1)"
    build_value="$(text "$MOD_ROOT/42/mod.info" | sed -n "s/^$key=//p" | head -1)"
    [[ "$root_value" == "$build_value" ]] || fail "mod.info and 42/mod.info disagree on '$key=' ('$root_value' vs '$build_value')"
  done
fi

# Through v1.0.1 the build version was a literal repeated in more than a dozen
# runtime Lua files. It is now defined once in the shared Version module (see
# "Build stamp and version handshake" in docs/DESIGN.md); every other file
# requires it.
VERSION_LUA="$RUNTIME_LUA/shared/EnshroudedSleep/Version.lua"
if [[ ! -f "$VERSION_LUA" ]]; then
  fail "$VERSION_LUA is missing"
elif ! grep -Eq 'BUILD_VERSION[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' "$VERSION_LUA"; then
  fail "$VERSION_LUA does not define BUILD_VERSION = \"x.y.z\""
fi
if [[ -d "$RUNTIME_LUA" ]] && grep -RnE --include='*.lua' \
     '(BUILD_VERSION|buildVersion)[[:space:]]*=[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"|Loaded v[0-9]+\.[0-9]+\.[0-9]+|Enshrouded Sleep v[0-9]+\.[0-9]+\.[0-9]+' \
     "$RUNTIME_LUA" | grep -v '/shared/EnshroudedSleep/Version\.lua:'; then
  fail "runtime Lua outside shared/EnshroudedSleep/Version.lua hard-codes the build version; require \"EnshroudedSleep/Version\" instead"
fi

# ---------------------------------------------------------------------------

mode="pre-publication"
[[ "$PUBLISHING" -eq 1 ]] && mode="publishing (Workshop ID $WORKSHOP_ID)"
echo "Checked $MOD_ID v$VERSION_VALUE in $mode mode: $errors error(s), $warnings warning(s)."
[[ "$errors" -eq 0 ]]
