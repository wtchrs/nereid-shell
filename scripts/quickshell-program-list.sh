#!/usr/bin/env bash
set -euo pipefail

AWK_SCRIPT="@awkFile@"
FIND="@find@"
AWK="@awk@"
JQ="@jq@"
UMU_EXE_LIST="@umuExeList@"

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

umu_json="[]"
if [[ -x "$UMU_EXE_LIST" ]] || command -v umu-exe-list >/dev/null 2>&1; then
    if [[ -x "$UMU_EXE_LIST" ]]; then
        umu_list_cmd="$UMU_EXE_LIST"
    else
        umu_list_cmd="$(command -v umu-exe-list)"
    fi

    if ! umu_json="$("$umu_list_cmd" 2>/dev/null)" || ! printf '%s\n' "$umu_json" | "$JQ" -e 'type == "array"' >/dev/null; then
        umu_json="[]"
    fi
fi

"$JQ" -c -s 'add' <(printf '%s\n' "$desktop_json") <(printf '%s\n' "$umu_json")
