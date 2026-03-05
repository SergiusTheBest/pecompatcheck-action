#!/bin/bash
# get-pe-arch.sh - Prints the architecture of a PE file using readpe to stdout.
#
# Requirements:
#   - readpe (install with: sudo apt-get install readpe)
#   - awk (should be installed by default)
#
# Usage:
#   ./get-pe-arch.sh /path/to/file.dll
#
# Output:
#   x86   - for 32-bit Intel (0x14c)
#   x64   - for 64-bit AMD64 (0x8664)
#   arm64 - for ARM64 (0xaa64)
#   <hex> - raw machine type value for unknown architectures
set -e

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <binary.dll|.exe|.sys>"
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

# Parse readpe output for Machine field in COFF header, map to architecture name.
ARCH=$(readpe -h coff "$BIN" 2>/dev/null | \
    awk '
        /^[[:space:]]*Machine:[[:space:]]+/ {
            # Extract hex value (e.g., 0x8664)
            match($0, /0x[0-9a-fA-F]+/)
            if (RSTART > 0) {
                hex = substr($0, RSTART, RLENGTH)
                # Map known architectures
                if (hex == "0x14c") print "x86"
                else if (hex == "0x8664") print "x64"
                else if (hex == "0xaa64") print "arm64"
                else print hex
            }
            exit
        }
    ')

if [[ -z "$ARCH" ]]; then
    echo "Error: Unable to determine PE architecture for '$BIN'."
    exit 5
fi

echo "$ARCH"
