#!/usr/bin/env bash
set -euo pipefail

AWK_SCRIPT="@awkFile@"
FIND="@find@"
AWK="@awk@"
JQ="@jq@"
PROGRAM_PROVIDERS_FILE="@programProvidersFile@"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DATA_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
FLATPAK_USER="$HOME/.local/share/flatpak/exports/share"
FLATPAK_SYSTEM="/var/lib/flatpak/exports/share"

IFS=':' read -r -a DIRS <<<"$DATA_HOME:$DATA_DIRS:$FLATPAK_USER:$FLATPAK_SYSTEM"
DESKTOP_ENV="${XDG_CURRENT_DESKTOP:-}"

HAS_FLATPAK=0
command -v flatpak >/dev/null 2>&1 && HAS_FLATPAK=1

desktop_json="$(
    for base in "${DIRS[@]}"; do
        appdir="$base/applications"
        [[ -d "$appdir" ]] || continue
        "$FIND" "$appdir" \( -type f -o -type l \) -name '*.desktop' -print 2>/dev/null
    done |
        "$AWK" -v env="$DESKTOP_ENV" -v has_flatpak="$HAS_FLATPAK" -f "$AWK_SCRIPT"
)"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

json_inputs=()
printf '%s\n' "$desktop_json" >"$tmpdir/desktop.json"
json_inputs+=("$tmpdir/desktop.json")

if [[ -r "$PROGRAM_PROVIDERS_FILE" ]]; then
    provider_index=0
    while IFS= read -r provider || [[ -n "$provider" ]]; do
        [[ -n "$provider" ]] || continue
        [[ -x "$provider" ]] || continue

        if json="$("$provider" 2>/dev/null)" &&
            printf '%s\n' "$json" |
                "$JQ" -e 'type == "array" and all(.[]; type == "object" and (.name | type == "string") and (.exec | type == "string"))' >/dev/null; then
            provider_file="$tmpdir/provider-$provider_index.json"
            printf '%s\n' "$json" >"$provider_file"
            json_inputs+=("$provider_file")
            provider_index=$((provider_index + 1))
        fi
    done <"$PROGRAM_PROVIDERS_FILE"
fi

"$JQ" -c -s '
  add
  | unique_by(.id // (.name + "\u0000" + .exec))
' "${json_inputs[@]}"
