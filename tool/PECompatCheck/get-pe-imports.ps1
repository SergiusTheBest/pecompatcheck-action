#!/usr/bin/env pwsh
# get-pe-imports.ps1 - Prints names-only list of imported functions from a PE file using dumpbin to stdout.
#
# Requirements:
#   - dumpbin.exe (located at tools/windows/dumpbin.exe relative to this script)
#
# Usage:
#   ./get-pe-imports.ps1 <binary.dll|.exe|.sys>
#
# Skips imports with empty names.
# Output format: <DLL><TAB><FunctionName>

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

# Run dumpbin /imports
$output = & $dumpbin /nologo /imports $BIN 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "Error: Unable to parse PE imports from '$BIN'."
    exit 4
}

# Parse dumpbin /imports output.
#
# Format per DLL block (all lines are space-indented):
#   "    <DllName>"                        <- indent=4, plain name
#   "                <addr> Import ..."    <- indent>4, metadata, skip
#   "                     0 time ..."      <- indent>4, metadata, skip
#   "                  <hex> <FuncName>"   <- indent>4, import entry
#
# DLL name lines have exactly 4 leading spaces.
# Import entry lines have more than 4 leading spaces and match:
#   <spaces><hex-ordinal><spaces><FunctionName>
# Metadata lines are skipped by detecting that their second token is a long
# hex address or starts with a known keyword (Import, time, Index).

$currentDll = $null

# Matches an import entry: many leading spaces, hex ordinal, spaces, name
$entryPattern = '^\s+([0-9A-Fa-f]+)\s+(\S.*)'

# Second-token patterns that mark a metadata line rather than a function name
$metaPattern  = '^[0-9A-Fa-f]{6,}$|^Import|^time|^Index'

foreach ($rawLine in $output) {
    $line    = [string]$rawLine
    $trimmed = $line.TrimStart()

    if ($trimmed.Length -eq 0) { continue }

    $indent = $line.Length - $trimmed.Length

    # Stop at the Summary section
    if ($indent -eq 2 -and $trimmed -eq 'Summary') { break }

    # DLL name line: exactly 4 spaces of indentation
    if ($indent -eq 4) {
        $currentDll = $trimmed.Trim()
        continue
    }

    # Import entry line: deeper indentation, hex ordinal + function name
    if ($indent -gt 4 -and $null -ne $currentDll -and $line -match $entryPattern) {
        $name = $Matches[2].Trim()
        # Skip metadata lines (long hex address or known keyword as second token)
        if ($name -match $metaPattern) { continue }
        if (-not [string]::IsNullOrWhiteSpace($name)) {
            Write-Output "$currentDll`t$name"
        }
    }
}
