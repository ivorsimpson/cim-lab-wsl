[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PSScriptRoot 'dist\sussex-cim-bootstrap.ps1'),
    [switch]$Check
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$templatePath = Join-Path $PSScriptRoot 'script-template.ps1'
$content = Get-Content -Raw -LiteralPath $templatePath
$pattern = '(?m)^# \{\{EMBED_B64:(?<name>[A-Za-z0-9_]+)=(?<path>[^}]+)\}\}\r?$'
$content = [regex]::Replace($content, $pattern, {
    param($m)
    $source = Join-Path $PSScriptRoot $m.Groups['path'].Value
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing embedded source: $source" }
    $bytes = [IO.File]::ReadAllBytes($source)
    '$Embedded' + $m.Groups['name'].Value + " = '" + [Convert]::ToBase64String($bytes) + "'"
})
if ($content -match '\{\{EMBED_B64:') { throw 'One or more embed markers were not replaced.' }
$tokens=$null; $errors=$null
[System.Management.Automation.Language.Parser]::ParseInput($content,[ref]$tokens,[ref]$errors) | Out-Null
if ($errors.Count) { throw ($errors | ForEach-Object Message | Out-String) }
if ($Check) { Write-Host 'PASS: source files found and built script parses.' -ForegroundColor Green; exit 0 }
New-Item -ItemType Directory -Path (Split-Path $OutputPath) -Force | Out-Null
[IO.File]::WriteAllText($OutputPath,$content,[Text.UTF8Encoding]::new($true))
Write-Host "Built $OutputPath" -ForegroundColor Green
