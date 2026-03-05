#!/bin/bash
# resolve-pe-imports.sh - Verifies that all imported functions from a PE binary exist in baseline export files.
#
# Requirements:
#   - readpe (install with: sudo apt-get install readpe)
#   - awk (should be installed by default)
#   - get-pe-imports.sh (in same directory)
#   - get-pe-arch.sh (in same directory)
#
# Usage:
#   ./resolve-pe-imports.sh /path/to/binary.dll /path/to/baseline/directory
#
# Exit codes:
#   0: All imports resolved successfully
#   1: Wrong number of arguments
#   2: PE binary file not found
#   3: awk not found
#   4: readpe not found
#   5: Baseline directory not found or invalid
#   6: get-pe-imports.sh execution failed
#   7: Missing imports found (unresolved dependencies)
#   8: Failed to determine PE architecture
set -e

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <binary.dll|.exe> <baseline_directory>"
    exit 1
fi

BIN="$1"
BASELINE_DIR="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check PE binary file exists
if [[ ! -f "$BIN" ]]; then
    echo "Error: File '$BIN' does not exist."
    exit 2
fi

# Check awk is available
if ! command -v awk &>/dev/null; then
    echo "Error: awk not found."
    echo "Install on Ubuntu: sudo apt-get update && sudo apt-get install gawk"
    exit 3
fi

# Check readpe is available
if ! command -v readpe &>/dev/null; then
    echo "Error: readpe not found."
    echo "Install on Ubuntu: sudo apt-get update && sudo apt-get install readpe"
    exit 4
fi

# Determine binary architecture and resolve baseline directory.
ARCH=$("$SCRIPT_DIR/get-pe-arch.sh" "$BIN" 2>/dev/null) || {
    echo "Error: Failed to determine architecture for '$BIN'."
    exit 8
}

BASELINE_DIR_TRIMMED="${BASELINE_DIR%/}"
[[ -z "$BASELINE_DIR_TRIMMED" ]] && BASELINE_DIR_TRIMMED="$BASELINE_DIR"

BASELINE_BASENAME=$(basename "$BASELINE_DIR_TRIMMED")

if [[ "$BASELINE_BASENAME" != "$ARCH" ]]; then
    BASELINE_DIR="$BASELINE_DIR_TRIMMED/$ARCH"
else
    BASELINE_DIR="$BASELINE_DIR_TRIMMED"
fi

# Check resolved baseline directory exists and is a directory
if [[ ! -d "$BASELINE_DIR" ]]; then
    echo "Error: Baseline directory '$BASELINE_DIR' not found or is not a directory."
    exit 5
fi

# Get imports from PE binary
IMPORTS=$("$SCRIPT_DIR/get-pe-imports.sh" "$BIN" 2>&1)
if [[ $? -ne 0 ]]; then
    echo "Error: Failed to extract imports from '$BIN'."
    exit 6
fi

# Declare associative arrays to track modules and their exports
declare -A module_exports
declare -A missing_imports
declare -A unique_modules
total_imports=0

# Process each import line
while IFS=$'\t' read -r module function; do
    # Skip empty lines
    [[ -z "$module" || -z "$function" ]] && continue
    
    total_imports=$((total_imports + 1))
    module_lower=$(echo "$module" | tr '[:upper:]' '[:lower:]')
    unique_modules["$module_lower"]=1
    
    # Load exports for this module if not already loaded
    if [[ -z "${module_exports[$module_lower]}" ]]; then
        export_file="$BASELINE_DIR/${module_lower}.exports"
        
        if [[ ! -f "$export_file" ]]; then
            # Module file not found - mark all imports from this module as missing
            module_exports["$module_lower"]="__NOT_FOUND__"
        else
            # Load exports from file
            exports=""
            while IFS= read -r export_name; do
                # Skip empty lines
                [[ -z "$export_name" ]] && continue
                exports+="$export_name"$'\n'
            done < "$export_file"
            module_exports["$module_lower"]="$exports"
        fi
    fi
    
    # Check if function exists in module's exports
    if [[ "${module_exports[$module_lower]}" == "__NOT_FOUND__" ]]; then
        missing_imports["$module"$'\t'"$function"]=1
    else
        # Check if the function is in the exports list
        if ! grep -q "^${function}$" <<< "${module_exports[$module_lower]}"; then
            missing_imports["$module"$'\t'"$function"]=1
        fi
    fi
done <<< "$IMPORTS"

# Calculate metrics
unique_module_count=${#unique_modules[@]}

# Check for missing imports
if [[ ${#missing_imports[@]} -eq 0 ]]; then
    echo "Success: resolved $total_imports imports from $unique_module_count modules"
    exit 0
else
    # Print all missing imports
    for missing in "${!missing_imports[@]}"; do
        echo "$missing"
    done | sort
    
    # Print error message to stderr
    echo "Error: Found ${#missing_imports[@]} unresolved imports." >&2
    exit 7
fi
