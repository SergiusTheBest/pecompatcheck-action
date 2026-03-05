#!/usr/bin/env pwsh
# get-pe-exports.ps1 - Prints names-only list of exported functions from a PE file using dumpbin to stdout.
#
# Requirements:
#   - dumpbin.exe (located at tools/windows/dumpbin.exe relative to this script)
#
# Usage:
#   ./get-pe-exports.ps1 <binary.dll|.exe|.sys>
#
# Skips exports with empty names and [NONAME] entries.

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

# Run dumpbin /exports
$output = & $dumpbin /nologo /exports $BIN 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "Error: Unable to parse PE exports from '$BIN'."
    exit 4
}

# Parse out the "name" column from the exports table (names-only)
$inTable = $false
$nameCol = -1
$sawData = $false

foreach ($line in $output) {
    $line = [string]$line

    if (-not $inTable) {
        if ($line -match '^\s*ordinal\s+hint\s+rva\s+name\b') {
            $inTable = $true
            $nameCol = $line.ToLower().IndexOf('name')
            continue
        }
        continue
    }

    # Once in table:
    if ($line.Trim().Length -eq 0) {
        if ($sawData) { break } else { continue }
    }

    # Expect data lines start with an ordinal (number)
    if ($line -notmatch '^\s*\d+') { continue }

    $sawData = $true

    $name = $null
    if ($nameCol -ge 0 -and $line.Length -gt $nameCol) {
        $name = $line.Substring($nameCol).Trim()
    } else {
        # Fallback: split on whitespace and take last token
        $tokens = $line -split '\s+'
        if ($tokens.Count -gt 0) { $name = $tokens[-1].Trim() }
    }

    if (-not [string]::IsNullOrWhiteSpace($name)) {
        # Remove forwarder suffix like: "FuncX (forwarded to KERNEL32.FuncX)"
        $name = ($name -replace '\s+\(forwarded to .*\)$', '').Trim()
        # Filter out entries that indicate lack of name ([NONAME], (ordinal-only))
        if ($name -ne '(ordinal-only)' -and $name -ne '[NONAME]') {
            Write-Output $name
        }
    }
}
