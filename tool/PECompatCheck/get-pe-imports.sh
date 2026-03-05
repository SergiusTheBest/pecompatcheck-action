#!/bin/bash
# get-pe-imports.sh - Prints names-only list of imported functions from a PE file using readpe to stdout.
#
# Requirements:
#   - readpe (install with: sudo apt-get install readpe)
#   - awk (should be installed by default)
#
# Usage:
#   ./get-pe-imports.sh /path/to/file.dll
#
# Skips imports with empty names.
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

# Parse readpe output for imported functions with their module names, print to stdout in two columns.
set +e
OUTPUT=$(readpe -i "$BIN" 2>&1)
EXIT_CODE=$?
set -e

if [[ $EXIT_CODE -ne 0 ]]; then
    echo "Error: Unable to parse PE imports from '$BIN'."
    exit 5
fi

echo "$OUTPUT" | \
    awk '
        {
            # First, extract and remove any trailing keyword from the line
            line_content = $0
            has_keyword = 0
            
            if(match(line_content, /^[[:space:]]*(Library|Functions|Function|Hint|Name|Imported)/)) {
                keyword = substr(line_content, RSTART, RLENGTH)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", keyword)
                line_prefix = substr(line_content, 1, RSTART-1)
                has_keyword = 1
            } else {
                keyword = ""
                line_prefix = line_content
            }
            
            # Process any continuation text before the keyword
            if(pending_name != "") {
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", line_prefix)
                if(line_prefix != "") {
                    pending_name = pending_name line_prefix
                }
            }
            
            # Now process the keyword
            if(keyword == "Library") {
                if(pending_name != "" && current_dll != "" && in_function) {
                    print current_dll "\t" pending_name
                }
                in_library = 1
                in_function = 0
                in_functions_section = 0
                pending_name = ""
            } else if(keyword == "Functions") {
                if(pending_name != "") {
                    current_dll = pending_name
                    pending_name = ""
                }
                in_functions_section = 1
                in_library = 0
            } else if(keyword == "Function") {
                if(in_functions_section) {
                    if(pending_name != "" && current_dll != "") {
                        print current_dll "\t" pending_name
                        pending_name = ""
                    }
                    in_function = 1
                }
            } else if(match(line_content, /^[[:space:]]*Name:[[:space:]]+/)) {
                name = substr(line_content, RSTART+RLENGTH)
                gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
                pending_name = name
            }
        }
        END {
            if(pending_name != "" && current_dll != "" && in_function) {
                print current_dll "\t" pending_name
            }
        }
    '
