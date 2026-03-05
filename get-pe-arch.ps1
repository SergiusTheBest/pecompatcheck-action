#!/usr/bin/env pwsh
# get-pe-arch.ps1 - Prints the architecture of a PE file using dumpbin to stdout.
#
# Requirements:
#   - dumpbin.exe (located at tools/windows/dumpbin.exe relative to this script)
#
# Usage:
#   ./get-pe-arch.ps1 <binary.dll|.exe|.sys>
#
# Output:
#   x86   - for 32-bit Intel (0x14c)
#   x64   - for 64-bit AMD64 (0x8664)
#   arm64 - for ARM64 (0xaa64)
#   <hex> - raw machine type value for unknown architectures

if ($args.Count -lt 1) {
    Write-Error "Usage: $($MyInvocation.MyCommand.Name) <binary.dll|.exe|.sys>"
    exit 1
}

$BIN = $args[0]

if (-not (Test-Path -LiteralPath $BIN)) {
    Write-Error "Error: File '$BIN' does not exist."
    exit 2
}

# Locate dumpbin.exe relative to this script
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
$dumpbin = Join-Path $scriptDir 'tools/windows/dumpbin.exe'

if (-not (Test-Path -LiteralPath $dumpbin)) {
    Write-Error "Error: dumpbin.exe not found at: $dumpbin"
    exit 3
}

# Run dumpbin /headers
$output = & $dumpbin /nologo /headers $BIN 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "Error: Unable to parse PE headers from '$BIN'."
    exit 4
}

# Parse the machine line from the FILE HEADER section, e.g.: "14C machine (x86)"
$ARCH = $null
foreach ($line in $output) {
    $line = [string]$line
    if ($line -match '^\s*([0-9a-fA-F]+)\s+machine\b') {
        $hex = $Matches[1].ToLower()
        $ARCH = switch ($hex) {
            '14c'  { 'x86' }
            '8664' { 'x64' }
            'aa64' { 'arm64' }
            default { "0x$hex" }
        }
        break
    }
}

if (-not $ARCH) {
    Write-Error "Error: Unable to determine PE architecture for '$BIN'."
    exit 5
}

Write-Output $ARCH
