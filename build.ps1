# ============================================================================
# build.ps1 — assembles the distributable new-cuda-project.ps1
# ----------------------------------------------------------------------------
# Reads script-template.ps1, finds each `# {{TEMPLATE: $var = path}}` marker,
# replaces it with a single-quoted here-string containing the corresponding
# file, and writes the result to dist/new-cuda-project.ps1.
#
# Unlike the pytorch sister build, marker paths are resolved from the
# bootstrap root, so both `linux/ensure-cuda.sh` and `template/main.cu` can
# be referenced. (The cuda bootstrap has two source trees: linux/ for bash
# scripts that run inside WSL, and template/ for the C++ project skeleton.)
#
# Usage:
#     .\build.ps1                       # build to dist\new-cuda-project.ps1
#     .\build.ps1 -OutputPath foo.ps1   # build to a custom path
#     .\build.ps1 -Check                # parse-check sources, don't write
# ============================================================================

[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'dist\new-cuda-project.ps1'),
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$Root         = $PSScriptRoot
$TemplatePath = Join-Path $Root 'script-template.ps1'

if (-not (Test-Path $TemplatePath)) {
    throw "script-template.ps1 not found at $TemplatePath"
}

# Read the script template as a single string (preserves CRLF/LF as-is, so
# the output line endings match what the user committed).
$content = [System.IO.File]::ReadAllText($TemplatePath)

# Match lines of the form:
#     # {{TEMPLATE: $VarName = relative/path/to/file}}
# Anchored to a full line. The marker comment must be the only thing on its
# line (leading whitespace is allowed). We capture the variable name and the
# relative path to the source file.
$markerPattern = '(?m)^[ \t]*#[ \t]*\{\{TEMPLATE:[ \t]*(\$\w+)[ \t]*=[ \t]*([^}]+?)[ \t]*\}\}[ \t]*\r?$'
$markerMatches = [regex]::Matches($content, $markerPattern)

if ($markerMatches.Count -eq 0) {
    throw "No {{TEMPLATE: ...}} markers found in $TemplatePath. Did the template format change?"
}

Write-Host "Found $($markerMatches.Count) template marker(s)" -ForegroundColor Cyan

# Substitute back-to-front so the earlier match offsets stay valid.
$ordered = $markerMatches | Sort-Object -Property Index -Descending
foreach ($m in $ordered) {
    $varName = $m.Groups[1].Value
    $relPath = $m.Groups[2].Value.Trim()
    # Marker paths are relative to the bootstrap root. Reject path-traversal
    # tricks (no leading "../" or absolute paths) so a typo in script-template
    # can't pull in random files outside the bootstrap dir.
    if ($relPath -match '^[\\/]' -or $relPath -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Marker path '$relPath' (for $varName) must be a relative path within the bootstrap directory."
    }
    $absPath = Join-Path $Root $relPath

    if (-not (Test-Path $absPath)) {
        throw "Template file '$relPath' (referenced by $varName) not found at $absPath"
    }

    $body = [System.IO.File]::ReadAllText($absPath)
    # Normalize line endings to LF (the runtime Write-LfFile re-normalizes
    # anyway, but a consistent here-string body keeps the built script
    # diff-clean across machines).
    $body = $body -replace "`r`n", "`n"
    # Trim exactly one trailing newline so the closing '@ sits on its own
    # line immediately after the body. Files that don't end in a newline are
    # left untouched.
    if ($body.EndsWith("`n")) { $body = $body.Substring(0, $body.Length - 1) }

    # Safety check: a line starting with '@ at column 0 would terminate the
    # single-quoted here-string. None of our templates have this today, but
    # someone editing the templates could trip it.
    if ($body -match "(?m)^'@") {
        throw "Template '$relPath' contains a line beginning with the sequence '@, which would prematurely terminate the single-quoted here-string in the built script. Restructure that line."
    }

    $replacement = "$varName = @'`n$body`n'@"
    $content = $content.Substring(0, $m.Index) + $replacement + $content.Substring($m.Index + $m.Length)

    Write-Host "  embedded $varName <- $relPath ($($body.Length) chars)" -ForegroundColor DarkGray
}

# Parse-check the assembled script so we catch syntax errors at build time
# rather than after students download it.
$parseErrors = $null
$null = [System.Management.Automation.Language.Parser]::ParseInput($content, [ref]$null, [ref]$parseErrors)
if ($parseErrors -and $parseErrors.Count -gt 0) {
    $msg = ($parseErrors | ForEach-Object {
        "  line $($_.Extent.StartLineNumber): $($_.Message)"
    }) -join "`n"
    throw "Built script has PowerShell parse errors:`n$msg"
}
Write-Host "Parse check: OK" -ForegroundColor Green

if ($Check) {
    Write-Host "-Check set; not writing output." -ForegroundColor Yellow
    return
}

$outDir = Split-Path -Parent $OutputPath
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

# Write as UTF-8 without BOM (matches the original script's encoding and
# avoids the BOM-confused-PowerShell-5.1 footgun).
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($OutputPath, $content, $utf8NoBom)

Write-Host "Built: $OutputPath" -ForegroundColor Green
