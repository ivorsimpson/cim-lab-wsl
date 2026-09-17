# Sussex CIM WSL/CUDA bootstrap

Maintainable source for the single-file student bootstrap.

## Layout

- `script-template.ps1`: Windows orchestration and embedded-file markers.
- `linux/prepare-distro.sh`: Ubuntu packages, student account and WSL configuration.
- `linux/check-gpu.sh`: NVIDIA visibility test.
- `linux/install-uv.sh`: pinned uv installer.
- `linux/install-cuda-toolkit.sh`: optional compiler toolkit.
- `linux/create-project.sh`: Python environment, packages, templates and CUDA test.
- `build.ps1`: embeds the Linux scripts as Base64 and writes `dist/sussex-cim-bootstrap.ps1`.
- `tests/test-source.ps1`: PowerShell parse/build checks and Bash syntax checks inside the selected WSL distribution.

## Build and test on Windows

```powershell
.\build.ps1 -Check
.\tests\test-source.ps1
.\build.ps1
```

## Smoke test

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\dist\sussex-cim-bootstrap.ps1 -Name cim-modular-smoke -SkipLaunch
```

The distributable remains one `.ps1` file. Edit the modular source files, rebuild, test, and commit both the sources and regenerated `dist` artifact.

## Build compatibility

The embed-marker regular expression is CRLF-safe for Windows PowerShell 5.1.

## Windows-path handling

The test runner transfers each Bash source to WSL as Base64 and runs `bash -n` from standard input. It does not pass a `C:\...` path to an ambiguous Windows `bash.exe`.

## VS Code launch

The generated script launches the Windows VS Code CLI from PowerShell with `--remote wsl+<distro> <Linux path>`. It does not execute `Code.exe` from inside WSL.

## Native stderr handling

Windows PowerShell 5.1 can turn native stderr progress messages into terminating errors when `$ErrorActionPreference` is `Stop`. `Invoke-Native` temporarily uses `Continue` and treats the native process exit code as authoritative.

## Idempotent virtual environments

`create-project.sh` reuses a valid `.venv` when its Python minor version matches the requested version. It recreates the environment only when it is incomplete or uses a different Python minor version.

## Native progress display

The PowerShell wrapper merges native stderr into ordinary console output. Installer progress remains visible without being displayed as a `NativeCommandError`; the process exit code remains authoritative.
