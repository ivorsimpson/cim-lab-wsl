[CmdletBinding()]
param(
    [string]$Distro = 'LabGPU'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$buildScript = Join-Path $projectRoot 'build.ps1'
$linuxDir = Join-Path $projectRoot 'linux'

Write-Host 'Checking PowerShell build and generated script...' -ForegroundColor Cyan
& $buildScript -Check
if ($LASTEXITCODE -ne 0) {
    throw "build.ps1 -Check failed with exit code $LASTEXITCODE"
}

# Do not call a Windows bash.exe with a C:\ path. Depending on PATH, `bash`
# may be WSL Bash, Git Bash, or another installation, each with different
# Windows-path handling. Send each source file to WSL as Base64 and parse it
# from standard input instead.
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    $distros = @(& wsl.exe --list --quiet 2>$null | ForEach-Object {
        ($_ -replace "`0", '').Trim()
    } | Where-Object { $_ })

    if ($distros -contains $Distro) {
        Write-Host "Checking Bash sources inside WSL distribution $Distro..." -ForegroundColor Cyan

        Get-ChildItem -LiteralPath $linuxDir -Filter '*.sh' -File | Sort-Object Name | ForEach-Object {
            $base64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
            $command = "printf '%s' '$base64' | base64 --decode | bash -n"

            & wsl.exe -d $Distro -u root -- bash -lc $command
            $code = $LASTEXITCODE
            if ($code -ne 0) {
                throw "WSL bash -n failed for $($_.Name) with exit code $code"
            }

            Write-Host "PASS: $($_.Name)" -ForegroundColor Green
        }
    }
    else {
        Write-Warning "WSL distribution '$Distro' is not registered. Bash syntax checks were skipped."
    }
}
else {
    Write-Warning 'wsl.exe is unavailable. Bash syntax checks were skipped.'
}

Write-Host 'PASS: modular source checks completed.' -ForegroundColor Green
