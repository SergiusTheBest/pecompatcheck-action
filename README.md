# PECompatCheck Action

[![Test](https://github.com/sergiusthebest/pecompatcheck-action/actions/workflows/test.yml/badge.svg)](https://github.com/sergiusthebest/pecompatcheck-action/actions/workflows/test.yml)

A GitHub Action that validates Windows PE binary (DLL, EXE, SYS) compatibility against a target Windows version by resolving all imported APIs against a bundled baseline of known exports.

Built on top of [PECompatCheck](tool/PECompatCheck/README.md).

## Usage

```yaml
- uses: sergiusthebest/pecompatcheck-action@v1
  with:
    binary: build/MyDriver.sys
    windows-version: vista-sp2
```

Multiple binaries — one path per line:

```yaml
- uses: sergiusthebest/pecompatcheck-action@v1
  with:
    binary: |
      build/MyDriver.sys
      build/MyLib.dll
    windows-version: vista-sp2
```

The action fails the step if any imported function cannot be resolved in the target Windows version's baseline, giving you a list of every missing symbol.

## Inputs

| Input | Required | Description |
|---|---|---|
| `binary` | **yes** | Path(s) to the PE binaries to check (DLL, EXE, SYS). One path per line for multiple binaries. |
| `windows-version` | **yes** | Target Windows version. Must match a directory name under `tool/PECompatCheck/baseline/` (e.g. `vista-sp2`). |

## Supported Runners

| Runner | Supported |
|---|---|
| `ubuntu-*` | ✅ |
| `macos-*` | ✅ |
| `windows-*` | ✅ |

## Available Windows Baselines

| Value | Windows Version |
|---|---|
| `vista-sp2` | Windows Vista SP2 (6.0.6002.18005) — x86 and x64 |

## Examples

### Basic — check a single binary against Vista SP2

```yaml
jobs:
  compat:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: cmake --build build/

      - name: Check Vista SP2 compatibility
        uses: sergiusthebest/pecompatcheck-action@v1
        with:
          binary: build/MyDriver.sys
          windows-version: vista-sp2
```

### Check multiple binaries in one step

```yaml
jobs:
  compat:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: cmake --build build/

      - name: Check Vista SP2 compatibility
        uses: sergiusthebest/pecompatcheck-action@v1
        with:
          binary: |
            build/MyDriver.sys
            build/MyFilter.sys
            build/MyLib.dll
          windows-version: vista-sp2
```

## How It Works

1. Installs the required PE parser tool (`readpe` on Linux/macOS, uses the bundled `dumpbin.exe` on Windows).
2. Determines the architecture of the binary (x86, x64, arm64).
3. Resolves the architecture-specific baseline directory (e.g. `baseline/vista-sp2/x64`).
4. Extracts all imported functions from the binary.
5. Looks up every imported function in the baseline `.exports` files.
6. **Exits 0** and prints the count of resolved imports if everything matched.
7. **Exits non-zero** and prints each unresolved symbol with its source module if anything is missing.

## Exit Codes

The action propagates exit codes from the underlying scripts directly:

| Code | Meaning |
|---|---|
| `0` | All imports resolved — binary is compatible |
| `7` | One or more imports could not be resolved — binary is **not** compatible |
| Other | Unexpected error (bad path, missing tool, etc.) |

## License

MIT — see [LICENSE](LICENSE).
