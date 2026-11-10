#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
output_directory="${1:-$project_root/build/apple-scpt}"
source_directory="$project_root/apple-scripts/terminal"
mkdir -p "$output_directory"
combined_source="$(mktemp "${TMPDIR:-/tmp}/shuttle-terminal.XXXXXX")"
trap 'rm -f "$combined_source"' EXIT

for name in terminal-new-window terminal-new-tab-default terminal-current-window; do
    cat "$source_directory/$name.applescript" > "$combined_source"
    # A newline is required because some historical source files have none.
    printf '\n' >> "$combined_source"
    cat "$source_directory/terminal-common.applescript" >> "$combined_source"
    /usr/bin/osacompile -l AppleScript -o "$output_directory/$name.scpt" "$combined_source"
done
