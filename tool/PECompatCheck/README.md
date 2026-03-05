# PECompatCheck

Simple bash scripts to analyze Windows PE (Portable Executable) files and validate whether binaries—especially drivers—can run on a specific Windows version.

## Description

This repository contains four complementary tools for analyzing Windows PE files:
- **get-pe-exports.sh**: Extracts exported function names from PE files
- **get-pe-imports.sh**: Extracts imported function names (with their source DLL) from PE files
- **get-pe-arch.sh**: Determines the architecture (x86, x64, arm64) of PE files
- **resolve-pe-imports.sh**: Validates that all imported functions exist in a baseline directory

The main goal is driver compatibility validation: check whether a PE binary can run on a target Windows version by resolving all imported APIs against that version's baseline exports.

All tools use the `readpe` utility to parse PE files and output clean, plain text lists. This is useful for analyzing Windows binaries, understanding their APIs, and validating compatibility with older Windows targets.

## Included Baseline Windows Versions

Current bundled baseline data:

- **Windows Vista SP2** (`6.0.6002.18005`)
  - `baseline/vista-sp2/x86`
  - `baseline/vista-sp2/x64`

You can add additional Windows version baselines under `baseline/` using the same structure.

## Features

### get-pe-exports.sh
- Extracts all exported function names from PE files (DLL/EXE)
- Outputs clean, plain text list of function names
- Skips exports with empty names
- Includes error checking for missing dependencies and invalid files

### get-pe-imports.sh
- Extracts all imported function names from PE files (DLL/EXE)
- Outputs two-column format: source DLL/module name and imported function name
- Skips imports with empty names
- Includes error checking for missing dependencies and invalid files

### get-pe-arch.sh
- Determines the architecture of PE files (DLL/EXE/SYS)
- Outputs architecture as: `x86`, `x64`, or `arm64`
- For unknown architectures, outputs the raw machine type hex value
- Includes error checking for missing dependencies and invalid files

### resolve-pe-imports.sh
- Validates that all imported functions from a PE binary exist in baseline export files
- Automatically resolves architecture-specific baseline path (e.g., appends `x86`, `x64`, or `arm64` when needed)
- Case-insensitive module name matching
- Reports total count of resolved imports and modules on success
- Lists all unresolved imports with their source modules on failure
- Supports batch validation (checks all imports before reporting results)
- Proper separation of output (results to stdout, errors to stderr)

### General
- Works on Linux systems (useful for cross-platform development and analysis)
- Easy integration into automation pipelines

## Requirements

- **readpe**: PE file parser
- **awk**: Text processing tool
- **bash**: Bourne Again Shell

## Usage

### get-pe-exports.sh

Extract exported function names:

```bash
./get-pe-exports.sh <path/to/binary.dll|.exe>
```

#### Examples

Extract exports from a DLL:
```bash
./get-pe-exports.sh /path/to/library.dll
```

Save output to a file:
```bash
./get-pe-exports.sh library.dll > exports.txt
```

Count the number of exports:
```bash
./get-pe-exports.sh library.dll | wc -l
```

Search for specific functions:
```bash
./get-pe-exports.sh library.dll | grep "CreateFile"
```

### get-pe-imports.sh

Extract imported function names with their source DLL:

```bash
./get-pe-imports.sh <path/to/binary.dll|.exe>
```

#### Examples

Extract imports from an EXE:
```bash
./get-pe-imports.sh /path/to/program.exe
```

Save output to a file:
```bash
./get-pe-imports.sh program.exe > imports.txt
```

Filter imports from a specific DLL:
```bash
./get-pe-imports.sh program.exe | grep "^kernel32.dll"
```

Count imports from each DLL:
```bash
./get-pe-imports.sh program.exe | awk '{print $1}' | sort | uniq -c
```

Get only function names (second column):
```bash
./get-pe-imports.sh program.exe | awk '{print $2}'
```

### get-pe-arch.sh

Determine the architecture of a PE file:

```bash
./get-pe-arch.sh <path/to/binary.dll|.exe|.sys>
```

#### Examples

Check the architecture of a driver:
```bash
./get-pe-arch.sh /path/to/driver.sys
```

Output:
```
x64
```

Batch check multiple files:
```bash
for file in *.sys; do echo "$file: $(./get-pe-arch.sh "$file")"; done
```

Filter only x64 files:
```bash
for file in *.dll; do
  arch=$(./get-pe-arch.sh "$file" 2>/dev/null)
  if [[ "$arch" == "x64" ]]; then
    echo "$file"
  fi
done
```

Use in a script to verify architecture:
```bash
arch=$(./get-pe-arch.sh myapp.exe)
if [[ "$arch" != "x64" ]]; then
  echo "Error: Expected x64 binary but got $arch"
  exit 1
fi
```

### resolve-pe-imports.sh

Verify that all imported functions from a PE binary exist in a baseline directory of export files:

```bash
./resolve-pe-imports.sh <path/to/binary.dll|.exe> <baseline_directory>
```

If `<baseline_directory>` does not already end with the binary architecture, the script appends it automatically.

#### Description

This script validates whether all imported functions from a PE binary can be resolved against a baseline of export files. It's useful for checking if a binary's dependencies are fully satisfied by a set of available modules.

#### Examples

Check if serial.sys has all its imports resolved:
```bash
./resolve-pe-imports.sh serial.sys baseline/vista-sp2/
```

If `serial.sys` is `x64`, the script resolves this to `baseline/vista-sp2/x64` automatically.

Output on success:
```
Successfully resolved 70 imports from 3 modules
```

Output on failure (unresolved imports):
```
HAL.dll	CreateFile
KERNEL32.dll	WriteProcessMemory
Error: Found 2 unresolved imports.
```

#### Baseline Directory Format

The baseline directory should contain `.exports` files named after the modules. File naming pattern: `<module_name>.exports`

You can pass either:
- an architecture root directory (for example, `baseline/vista-sp2/`) and let the script append the detected architecture subdirectory, or
- a directory that already includes the architecture (for example, `baseline/vista-sp2/x64/`), in which case it is used as-is.

Example directory structure:
```
baseline/
  vista-sp2/
    x64/
      kernel32.dll.exports
      ntoskrnl.exe.exports
      hal.dll.exports
    x86/
      kernel32.dll.exports
      ntoskrnl.exe.exports
      hal.dll.exports
```

Each `.exports` file is a plain text file with one exported function name per line:
```
KdComPortInUse
CreateFileA
ReadFile
...
```

#### Module Name Matching

- Module names are case-insensitive (e.g., `KERNEL32.DLL`, `kernel32.dll`, and `Kernel32.dll` all match)
- The script appends `.exports` to the lowercase module name when searching for files
- All imported function names must exactly match function names in the corresponding export file

## Output Format

### get-pe-exports.sh

The script outputs one function name per line:

```
FunctionName1
FunctionName2
FunctionName3
...
```

### get-pe-imports.sh

The script outputs two tab-separated columns: source DLL name and imported function name:

```
kernel32.dll	CreateFileA
kernel32.dll	ReadFile
kernel32.dll	WriteFile
user32.dll	MessageBoxA
...
```

### get-pe-arch.sh

The script outputs the architecture on a single line:

```
x64
```

Possible outputs:
- `x86` - 32-bit Intel architecture (machine type 0x14c)
- `x64` - 64-bit AMD64/Intel 64 architecture (machine type 0x8664)
- `arm64` - 64-bit ARM architecture (machine type 0xaa64)
- `0x<hex>` - Raw machine type value for unknown architectures

## Error Codes

### get-pe-exports.sh, get-pe-imports.sh, and get-pe-arch.sh

- `1`: Invalid usage (no file specified)
- `2`: Specified file does not exist
- `3`: `awk` command not found
- `4`: `readpe` command not found
- `5`: Unable to parse PE file (not a valid PE file)

### resolve-pe-imports.sh

- `0`: All imports successfully resolved
- `1`: Wrong number of arguments (requires 2 parameters)
- `2`: PE binary file not found
- `3`: `awk` command not found
- `4`: `readpe` command not found
- `5`: Baseline directory not found or is not a directory
- `6`: Failed to extract imports (get-pe-imports.sh execution failed)
- `7`: Missing imports found (unresolved dependencies)
- `8`: Failed to determine PE architecture

## How It Works

### get-pe-exports.sh

1. Validates that a file path was provided
2. Checks if the file exists
3. Verifies that required tools (`awk` and `readpe`) are installed
4. Runs `readpe -e` to extract export information
5. Parses the output using `awk` to extract function names
6. Filters out empty names and outputs the clean list

### get-pe-imports.sh

1. Validates that a file path was provided
2. Checks if the file exists
3. Verifies that required tools (`awk` and `readpe`) are installed
4. Runs `readpe -i` to extract import information
5. Parses the output using `awk` to extract DLL names and imported function names
6. Filters out empty names and outputs the two-column list

### get-pe-arch.sh

1. Validates that a file path was provided
2. Checks if the file exists
3. Verifies that required tools (`awk` and `readpe`) are installed
4. Runs `readpe -h coff` to extract COFF header information
5. Parses the Machine field to get the machine type hex value
6. Maps known architectures (0x14c → x86, 0x8664 → x64, 0xaa64 → arm64)
7. Outputs the architecture name or raw hex value for unknown types

### resolve-pe-imports.sh

1. Validates that exactly 2 parameters are provided (PE binary and baseline directory)
2. Checks if the PE binary file exists
3. Verifies that required tools (`awk` and `readpe`) are installed
4. Detects PE architecture using `get-pe-arch.sh`
5. Resolves the effective baseline directory:
  - appends the detected architecture subdirectory if missing
  - keeps the path unchanged if it already ends with that architecture
6. Checks if the resolved baseline directory exists and is valid
7. Calls `get-pe-imports.sh` to extract all imports from the PE binary
8. For each unique module, loads the corresponding `.exports` file from the baseline directory (case-insensitive matching)
9. Validates that each imported function exists in its corresponding module's export file
10. Collects all unresolved imports (missing functions or missing modules)
11. Reports results:
   - **Success**: Prints total count of resolved imports and unique modules, exits with code 0
   - **Failure**: Lists all unresolved imports to stdout, error message to stderr, exits with code 7

## Use Cases

- **Driver Compatibility Validation**: Verify that driver binaries can run on specific (including older) Windows versions by resolving imports against version-specific baselines

- **Reverse Engineering**: Quickly identify exported and imported APIs in Windows binaries
- **API Documentation**: Generate function lists for documentation
- **Dependency Analysis**: 
  - Understand what functions a DLL provides (exports)
  - Discover what external functions a binary depends on (imports)
  - **Verify dependencies are satisfied** (resolve-pe-imports.sh)
- **Architecture Detection**:
  - Verify binary architecture before deployment
  - Sort binaries by architecture in build pipelines
  - Ensure correct architecture for target platform (x86, x64, arm64)
  - Batch analyze multiple PE files to identify their architectures
- **Security Analysis**: Identify which system APIs a binary uses
- **Cross-Platform Development**: Analyze Windows binaries on Linux systems
- **Automation**: Integrate into build scripts or analysis pipelines
- **Library Comparison**: Compare exported interfaces between different versions of DLLs
- **Baseline Validation**: Verify that PE binaries can run in a specific environment by checking if all their imports are provided by available modules (useful for containerization, cross-version compatibility checks, or sandboxed environments)

## License

MIT License - see [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Sergey Podobry

