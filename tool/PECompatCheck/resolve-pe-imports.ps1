#!/usr/bin/env pwsh
# resolve-pe-imports.ps1 - Verifies that all imported functions from a PE binary exist in baseline export files.
#
# Requirements:
#   - dumpbin.exe (located at tools/windows/dumpbin.exe relative to this script)
#   - get-pe-imports.ps1 (in same directory)
#   - get-pe-arch.ps1 (in same directory)
#
# Usage:
#   ./resolve-pe-imports.ps1 <binary.dll|.exe|.sys> <baseline_directory>
#
# Exit codes:
#   0: All imports resolved successfully
#   1: Wrong number of arguments
#   2: PE binary file not found
#   3: dumpbin.exe not found
#   5: Baseline directory not found or invalid
#   6: get-pe-imports.ps1 execution failed
#   7: Missing imports found (unresolved dependencies)
#   8: Failed to determine PE architecture

if ($args.Count -ne 2) {
    Write-Error "Usage: $($MyInvocation.MyCommand.Name) <binary.dll|.exe|.sys> <baseline_directory>"
    exit 1
}

$BIN         = $args[0]
$BASELINE    = $args[1]
$scriptDir   = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Check PE binary file exists
if (-not (Test-Path -LiteralPath $BIN)) {
    Write-Error "Error: File '$BIN' does not exist."
    exit 2
}

# Check dumpbin.exe is present (shared requirement of the sibling scripts)
$dumpbin = Join-Path $scriptDir 'tools/windows/dumpbin.exe'
if (-not (Test-Path -LiteralPath $dumpbin)) {
    Write-Error "Error: dumpbin.exe not found at: $dumpbin"
    exit 3
}

# Determine binary architecture
$getArch = Join-Path $scriptDir 'get-pe-arch.ps1'
$ARCH    = powershell -ExecutionPolicy Bypass -File $getArch $BIN 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($ARCH)) {
    Write-Error "Error: Failed to determine architecture for '$BIN'."
    exit 8
}
$ARCH = $ARCH.Trim()

# Resolve baseline directory: if the leaf name is not already the arch, append it
$baselineTrimmed = $BASELINE.TrimEnd('\', '/')
if ([string]::IsNullOrEmpty($baselineTrimmed)) { $baselineTrimmed = $BASELINE }
$baselineLeaf = Split-Path $baselineTrimmed -Leaf

if ($baselineLeaf -ne $ARCH) {
    $baselineResolved = Join-Path $baselineTrimmed $ARCH
} else {
    $baselineResolved = $baselineTrimmed
}

# Check resolved baseline directory exists
if (-not (Test-Path -LiteralPath $baselineResolved -PathType Container)) {
    Write-Error "Error: Baseline directory '$baselineResolved' not found or is not a directory."
    exit 5
}

# Get imports from PE binary
$getImports = Join-Path $scriptDir 'get-pe-imports.ps1'
$importLines = powershell -ExecutionPolicy Bypass -File $getImports $BIN 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Error: Failed to extract imports from '$BIN'."
    exit 6
}

# Hashtable of lowercase module name -> HashSet<string> of exports (or $null = file not found)
$moduleExports  = @{}
# Ordered list of missing "Module`tFunction" strings (using hashtable as set to deduplicate)
$missingImports = @{}
$uniqueModules  = @{}
$totalImports   = 0

foreach ($line in $importLines) {
    $line = [string]$line
    $tab  = $line.IndexOf("`t")
    if ($tab -lt 0) { continue }

    $module   = $line.Substring(0, $tab)
    $function = $line.Substring($tab + 1)
    if ([string]::IsNullOrWhiteSpace($module) -or [string]::IsNullOrWhiteSpace($function)) { continue }

    $totalImports++
    $moduleLower = $module.ToLower()
    $uniqueModules[$moduleLower] = 1

    # Load exports for this module if not already cached
    if (-not $moduleExports.ContainsKey($moduleLower)) {
        $exportFile = Join-Path $baselineResolved "$moduleLower.exports"
        if (-not (Test-Path -LiteralPath $exportFile)) {
            $moduleExports[$moduleLower] = $null
        } else {
            $set = [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::Ordinal
            )
            foreach ($exp in (Get-Content -LiteralPath $exportFile)) {
                if (-not [string]::IsNullOrWhiteSpace($exp)) { [void]$set.Add($exp.Trim()) }
            }
            $moduleExports[$moduleLower] = $set
        }
    }

    # Check if function exists in module exports
    $exports = $moduleExports[$moduleLower]
    if ($null -eq $exports -or -not $exports.Contains($function)) {
        $missingImports["$module`t$function"] = 1
    }
}

$uniqueModuleCount = $uniqueModules.Count

if ($missingImports.Count -eq 0) {
    Write-Output "Success: resolved $totalImports imports from $uniqueModuleCount modules"
    exit 0
} else {
    $missingImports.Keys | Sort-Object | ForEach-Object { Write-Output $_ }
    Write-Error "Error: Found $($missingImports.Count) unresolved imports."
    exit 7
}
