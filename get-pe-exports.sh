#!/bin/bash
# get-pe-exports.sh - Prints names-only list of exported functions from a PE file using readpe to stdout.
#
# Requirements:
#   - readpe (install with: sudo apt-get install readpe)
#   - awk (should be installed by default)
#
# Usage:
#   ./get-pe-exports.sh /path/to/file.dll
#
# Skips exports with empty names.
set -e

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <binary.dll|.exe>"
    exit 1
fi

BIN="$1"

if [[ ! -f "$BIN" ]]; then
    echo "Error: File '$BIN' does not exist."
    exit 2
fi

if ! command -v awk &>/dev/null; then
    echo "Error: awk not found."
    echo "Install on Ubuntu: sudo apt-get update && sudo apt-get install gawk"
    exit 3
fi

if ! command -v readpe &>/dev/null; then
    echo "Error: readpe not found."
    echo "Install on Ubuntu: sudo apt-get update && sudo apt-get install readpe"
    exit 4
fi

# Parse readpe output for non-empty Name: fields under Function blocks, print to stdout, and add a trailing newline.
set +e
OUTPUT=$(readpe -e "$BIN" 2>&1)
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Error: Unable to parse PE exports from '$BIN'."
    exit 5
fi

echo "$OUTPUT" | \
    awk '
        /^[[:space:]]*Function$/ { in_function=1; next }
        in_function && /^[[:space:]]*Name:[[:space:]]+/ {
            name=substr($0, index($0,":") +1)
            gsub(/^[[:space:]]+|[[:space:]]+$/,"",name)
            sub(/[[:space:]]*->[[:space:]]*.*/,"",name)
            gsub(/^[[:space:]]+|[[:space:]]+$/,"",name)
            if(name!="") print name
            in_function=0
        }
    '