# cuda-project-bootstrap

Source for the `new-cuda-project.ps1` bootstrap script distributed to
students. The built script is a single, self-contained `.ps1` that students
download and run. This directory holds the editable sources and a build
step that stitches them together.

## Layout

```
cuda-project-bootstrap/
├── README.md               (this file)
├── build.ps1               assembles the distributable script
├── script-template.ps1     the script logic, with {{TEMPLATE: ...}} markers
├── linux/                  bash scripts that run inside WSL
│   ├── bootstrap-distro.sh
│   ├── ensure-cuda.sh
│   └── make-project.sh
├── template/               files written into each generated project
│   ├── CMakeLists.txt
│   ├── main.cu
│   ├── README.md
│   ├── .gitignore
│   └── .vscode/
│       ├── settings.json
│       ├── extensions.json
│       ├── tasks.json
│       └── launch.json
└── dist/                   build output (committed for distribution)
    └── new-cuda-project.ps1
```

The `linux/` directory holds the bash scripts that get pushed inside WSL and
executed there. The `template/` directory mirrors the layout of the project
the bootstrap eventually generates. Edit both with normal tooling — VS Code
gives you shell + CMake + JSON syntax highlighting, which is the whole point
of splitting them out from the original monolithic script.

Runtime placeholders like `__PROJECT_NAME__`, `__CUDA_ARCH__`, and `__USER__`
survive the build verbatim and are substituted by `make-project.sh`'s `sed`
pass when a student runs the script.

## Build

```powershell
cd cuda-project-bootstrap
.\build.ps1                       # writes dist\new-cuda-project.ps1
.\build.ps1 -OutputPath foo.ps1   # custom output path
.\build.ps1 -Check                # parse-check sources, write nothing
```

`build.ps1` parses each `# {{TEMPLATE: $var = path}}` marker in
`script-template.ps1`, replaces it with a single-quoted here-string holding
the corresponding file's content, AST-parses the result, and writes the
combined script to `dist/`. Marker paths are resolved from the bootstrap
root, so both `linux/<file>` and `template/<file>` are valid.

## Editing workflow

1. Edit `template/<whatever>`, `linux/<whatever>`, or `script-template.ps1`.
2. Run `.\build.ps1`.
3. Test the built script with a dummy project name:

   ```powershell
   .\dist\new-cuda-project.ps1 -Name smoke-test
   # then, between iterations:
   wsl --shutdown                                # if any GPU call hangs
   wsl -d LabGPU -- rm -rf /home/$env:USERNAME/projects/smoke-test
   ```

4. Commit both the source changes and the regenerated `dist/` artifact.

## Adding a new template file

1. Drop the file into `template/` (or `linux/`) at the path you want it
   written to.
2. Add a `Write-LfFile` line in `script-template.ps1`'s extract section,
   pointing at the new file.
3. Add a `# {{TEMPLATE: $E_yourname = relpath/file }}` marker in the
   EMBEDDED FILES section.
4. Rebuild.

## Why WSL at all?

CUDA C++ on Windows needs MSVC as the host compiler, and MSVC needs Visual
Studio (admin). WSL sidesteps that — apt installs the toolkit user-mode and
g++ is the host compiler. The only one-time admin step is enabling WSL itself
(IT runs `wsl --install --no-distribution` once per machine); after that,
students provision distros + install CUDA bits entirely user-mode.

## Known-good lessons (don't re-discover)

- **`2>&1` on native exes in Windows PowerShell 5.1** wraps stderr in
  ErrorRecords and pollutes output arrays. `Invoke-WslBash` captures stderr
  to a temp file instead.
- **`nvidia-smi` can D-state hang** if the dxg connection to the Windows
  driver is stale. `timeout` can't kill it, `SIGKILL` can't kill it; only
  `wsl --shutdown` cures it. The installer therefore never calls
  `nvidia-smi` itself — it tells the student to run it and how to recover.
- **VS Code launch from PowerShell**: use `--folder-uri vscode-remote://wsl+<distro><path>`,
  not the bare `--remote wsl+<distro> /path` form. The latter is mangled by
  cmd.exe argv parsing and lands the user in an empty workbench.
- **`Start-Process` for the VS Code launch**, not `& code ...` — otherwise a
  parent shell piping the script's output hangs forever on Code.exe's
  inherited stdio handles.
- **CMakeLists fallback** for `CMAKE_CUDA_COMPILER` so raw `cmake ..` from
  `bash -c` (no PATH inheritance) still finds nvcc.
