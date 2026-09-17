#Requires -Version 5.1
<#
.SYNOPSIS
  Imports/reuses Ubuntu 24.04 on WSL 2 and creates a CUDA-enabled PyTorch project.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$')][string]$Name = 'cim-lab',
    [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$Distro = 'LabGPU',
    [string]$DistroRoot = (Join-Path $env:LOCALAPPDATA 'SussexWSL\LabGPU'),
    [ValidatePattern('^3\.(10|11|12|13|14)$')][string]$PythonVersion = '3.12',
    [ValidateSet('cu126','cu130','cu132','cpu')][string]$TorchChannel = 'cu126',
    [ValidatePattern('^torch([<>=!~][0-9A-Za-z.*+!<>=~-]+)?$')][string]$TorchSpec = 'torch',
    [ValidatePattern('^torchvision([<>=!~][0-9A-Za-z.*+!<>=~-]+)?$')][string]$TorchvisionSpec = 'torchvision',
    [string[]]$ExtraPackages = @('jupyterlab','matplotlib','numpy','pillow','scikit-image','scipy','tifffile','tqdm'),
    [ValidatePattern('^\d+\.\d+\.\d+$')][string]$UvVersion = '0.12.15',
    [switch]$InstallCudaToolkit,
    [switch]$ForceRecreateProject,
    [switch]$SkipLaunch
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$EmbeddedPrepareDistro = 'IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbAp1c2VyX25hbWU9JHsxOj9MaW51eCB1c2VybmFtZSBpcyByZXF1aXJlZH0KZXhwb3J0IERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQphcHQtZ2V0IHVwZGF0ZQphcHQtZ2V0IGluc3RhbGwgLXkgLS1uby1pbnN0YWxsLXJlY29tbWVuZHMgc3VkbyBwYXNzd2QgY2EtY2VydGlmaWNhdGVzIGN1cmwgZ2l0IGJ1aWxkLWVzc2VudGlhbCBwa2ctY29uZmlnCmluc3RhbGwgLWQgLW0gMDc1NSAvZXRjL3N1ZG9lcnMuZAppZiAhIGlkIC11ICIkdXNlcl9uYW1lIiA+L2Rldi9udWxsIDI+JjE7IHRoZW4KICB1c2VyYWRkIC0tY3JlYXRlLWhvbWUgLS1zaGVsbCAvYmluL2Jhc2ggIiR1c2VyX25hbWUiCmZpCnVzZXJtb2QgLWFHIHN1ZG8gIiR1c2VyX25hbWUiCnByaW50ZiAnJXMgQUxMPShBTEwpIE5PUEFTU1dEOkFMTFxuJyAiJHVzZXJfbmFtZSIgPiAvZXRjL3N1ZG9lcnMuZC85MC1jaW0tc3R1ZGVudApjaG1vZCAwNDQwIC9ldGMvc3Vkb2Vycy5kLzkwLWNpbS1zdHVkZW50CnZpc3VkbyAtLWNoZWNrIC0tZmlsZT0vZXRjL3N1ZG9lcnMuZC85MC1jaW0tc3R1ZGVudApwcmludGYgJyVzXG4nICdbYm9vdF0nICdzeXN0ZW1kPXRydWUnICdbdXNlcl0nICJkZWZhdWx0PSR1c2VyX25hbWUiID4gL2V0Yy93c2wuY29uZgpybSAtcmYgL3Zhci9saWIvYXB0L2xpc3RzLyoK'
$EmbeddedCheckGpu = 'IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbAppZiBjb21tYW5kIC12IG52aWRpYS1zbWkgPi9kZXYvbnVsbCAyPiYxOyB0aGVuCiAgZXhlYyBudmlkaWEtc21pCmVsaWYgW1sgLXggL3Vzci9saWIvd3NsL2xpYi9udmlkaWEtc21pIF1dOyB0aGVuCiAgZXhlYyAvdXNyL2xpYi93c2wvbGliL252aWRpYS1zbWkKZWxzZQogIGVjaG8gJ252aWRpYS1zbWkgd2FzIG5vdCBmb3VuZC4gQ2hlY2sgdGhlIFdpbmRvd3MgTlZJRElBIFdTTCBkcml2ZXIuJyA+JjIKICBleGl0IDEyNwpmaQo='
$EmbeddedInstallUv = 'IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbAp1dl92ZXJzaW9uPSR7MTo/dXYgdmVyc2lvbiBpcyByZXF1aXJlZH0KZXhwb3J0IFVWX05PX01PRElGWV9QQVRIPTEKY3VybCAtTHNTZiAiaHR0cHM6Ly9hc3RyYWwuc2gvdXYvJHt1dl92ZXJzaW9ufS9pbnN0YWxsLnNoIiB8IHNoCiIkSE9NRS8ubG9jYWwvYmluL3V2IiAtLXZlcnNpb24K'
$EmbeddedInstallCudaToolkitScript = 'IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbApleHBvcnQgREVCSUFOX0ZST05URU5EPW5vbmludGVyYWN0aXZlCmFwdC1nZXQgdXBkYXRlCmFwdC1nZXQgaW5zdGFsbCAteSAtLW5vLWluc3RhbGwtcmVjb21tZW5kcyBudmlkaWEtY3VkYS10b29sa2l0IGNtYWtlIG5pbmphLWJ1aWxkCnJtIC1yZiAvdmFyL2xpYi9hcHQvbGlzdHMvKgo='
$EmbeddedCreateProject = 'IyEvdXNyL2Jpbi9lbnYgYmFzaApzZXQgLWV1byBwaXBlZmFpbApwcm9qZWN0PSR7MTo/cHJvamVjdCBwYXRoIGlzIHJlcXVpcmVkfQpweXRob25fdmVyc2lvbj0kezI6P1B5dGhvbiB2ZXJzaW9uIGlzIHJlcXVpcmVkfQp0b3JjaF9jaGFubmVsPSR7Mzo/UHlUb3JjaCBjaGFubmVsIGlzIHJlcXVpcmVkfQp0b3JjaF9zcGVjPSR7NDo/dG9yY2ggc3BlYyBpcyByZXF1aXJlZH0KdG9yY2h2aXNpb25fc3BlYz0kezU6P3RvcmNodmlzaW9uIHNwZWMgaXMgcmVxdWlyZWR9CmZvcmNlX3JlY3JlYXRlPSR7NjotZmFsc2V9CnNoaWZ0IDYKZXh0cmFfcGFja2FnZXM9KCIkQCIpCgpleHBvcnQgUEFUSD0iJEhPTUUvLmxvY2FsL2JpbjovdXNyL2xvY2FsL3NiaW46L3Vzci9sb2NhbC9iaW46L3Vzci9zYmluOi91c3IvYmluOi9zYmluOi9iaW46L3Vzci9saWIvd3NsL2xpYiIKdXY9IiRIT01FLy5sb2NhbC9iaW4vdXYiCmlmIFtbICIkZm9yY2VfcmVjcmVhdGUiID09IHRydWUgXV07IHRoZW4gcm0gLXJmIC0tICIkcHJvamVjdCI7IGZpCm1rZGlyIC1wICIkcHJvamVjdC9zcmMiICIkcHJvamVjdC9ub3RlYm9va3MiICIkcHJvamVjdC9kYXRhIgpjZCAiJHByb2plY3QiCnByaW50ZiAnJXNcbicgIiRweXRob25fdmVyc2lvbiIgPiAucHl0aG9uLXZlcnNpb24KIiR1diIgcHl0aG9uIGluc3RhbGwgIiRweXRob25fdmVyc2lvbiIKCnJlY3JlYXRlX3ZlbnY9ZmFsc2UKaWYgW1sgLWUgLnZlbnYgJiYgISAteCAudmVudi9iaW4vcHl0aG9uIF1dOyB0aGVuCiAgcmVjcmVhdGVfdmVudj10cnVlCmVsaWYgW1sgLXggLnZlbnYvYmluL3B5dGhvbiBdXTsgdGhlbgogIGV4aXN0aW5nX21pbm9yPSQoLnZlbnYvYmluL3B5dGhvbiAtYyAnaW1wb3J0IHN5czsgcHJpbnQoZiJ7c3lzLnZlcnNpb25faW5mby5tYWpvcn0ue3N5cy52ZXJzaW9uX2luZm8ubWlub3J9IiknKQogIGlmIFtbICIkZXhpc3RpbmdfbWlub3IiICE9ICIkcHl0aG9uX3ZlcnNpb24iIF1dOyB0aGVuCiAgICByZWNyZWF0ZV92ZW52PXRydWUKICBmaQpmaQoKaWYgW1sgIiRyZWNyZWF0ZV92ZW52IiA9PSB0cnVlIF1dOyB0aGVuCiAgcm0gLXJmIC52ZW52CmZpCmlmIFtbICEgLXggLnZlbnYvYmluL3B5dGhvbiBdXTsgdGhlbgogICIkdXYiIHZlbnYgLS1weXRob24gIiRweXRob25fdmVyc2lvbiIKZWxzZQogIGVjaG8gIlJldXNpbmcgZXhpc3RpbmcgLnZlbnYgd2l0aCBQeXRob24gJHB5dGhvbl92ZXJzaW9uIgpmaQoKIiR1diIgcGlwIGluc3RhbGwgLS1weXRob24gLnZlbnYvYmluL3B5dGhvbiAiJHRvcmNoX3NwZWMiICIkdG9yY2h2aXNpb25fc3BlYyIgXAogIC0taW5kZXgtdXJsICJodHRwczovL2Rvd25sb2FkLnB5dG9yY2gub3JnL3dobC8kdG9yY2hfY2hhbm5lbCIKIiR1diIgcGlwIGluc3RhbGwgLS1weXRob24gLnZlbnYvYmluL3B5dGhvbiAiJHtleHRyYV9wYWNrYWdlc1tAXX0iCnsKICBwcmludGYgJyVzXG4nICIkdG9yY2hfc3BlYyIgIiR0b3JjaHZpc2lvbl9zcGVjIgogIHByaW50ZiAnJXNcbicgIiR7ZXh0cmFfcGFja2FnZXNbQF19Igp9ID4gcmVxdWlyZW1lbnRzLWxhYi50eHQKY2F0ID4gc3JjL2NoZWNrX2dwdS5weSA8PCdQWUNPREUnCmltcG9ydCBwbGF0Zm9ybQppbXBvcnQgc3lzCmltcG9ydCB0b3JjaAoKcHJpbnQoZiJQeXRob246IHtzeXMudmVyc2lvbi5zcGxpdCgpWzBdfSIpCnByaW50KGYiUGxhdGZvcm06IHtwbGF0Zm9ybS5wbGF0Zm9ybSgpfSIpCnByaW50KGYiUHlUb3JjaDoge3RvcmNoLl9fdmVyc2lvbl9ffSIpCnByaW50KGYiUHlUb3JjaCBDVURBIHJ1bnRpbWU6IHt0b3JjaC52ZXJzaW9uLmN1ZGF9IikKcHJpbnQoZiJDVURBIGF2YWlsYWJsZToge3RvcmNoLmN1ZGEuaXNfYXZhaWxhYmxlKCl9IikKaWYgbm90IHRvcmNoLmN1ZGEuaXNfYXZhaWxhYmxlKCk6CiAgICByYWlzZSBTeXN0ZW1FeGl0KCJFUlJPUjogdGhpcyBQeVRvcmNoIGVudmlyb25tZW50IGNhbm5vdCBhY2Nlc3MgQ1VEQSIpCnByaW50KGYiR1BVOiB7dG9yY2guY3VkYS5nZXRfZGV2aWNlX25hbWUoMCl9IikKYSA9IHRvcmNoLnJhbmRuKCgxMDI0LCAxMDI0KSwgZGV2aWNlPSJjdWRhIikKYiA9IHRvcmNoLnJhbmRuKCgxMDI0LCAxMDI0KSwgZGV2aWNlPSJjdWRhIikKYyA9IGEgQCBiCnRvcmNoLmN1ZGEuc3luY2hyb25pemUoKQphc3NlcnQgYy5pc19jdWRhIGFuZCB0b3JjaC5pc2Zpbml0ZShjKS5hbGwoKQpwcmludCgiUEFTUzogUHlUb3JjaCBjb21wbGV0ZWQgYSBDVURBIG1hdHJpeCBtdWx0aXBsaWNhdGlvbiIpClBZQ09ERQpjYXQgPiBSRUFETUUubWQgPDwnTUFSS0RPV04nCiMgQ29tcHV0YXRpb25hbCBJbWFnaW5nIE1ldGhvZHMgbGFiCgpSdW4gdGhlIEdQVSBjaGVjazoKCiAgICB+Ly5sb2NhbC9iaW4vdXYgcnVuIC0tcHl0aG9uIC52ZW52L2Jpbi9weXRob24gcHl0aG9uIHNyYy9jaGVja19ncHUucHkKClN0YXJ0IEp1cHl0ZXJMYWI6CgogICAgfi8ubG9jYWwvYmluL3V2IHJ1biAtLXB5dGhvbiAudmVudi9iaW4vcHl0aG9uIGp1cHl0ZXIgbGFiIC0tbm8tYnJvd3NlcgpNQVJLRE9XTgoiJHV2IiBydW4gLS1weXRob24gLnZlbnYvYmluL3B5dGhvbiBweXRob24gc3JjL2NoZWNrX2dwdS5weQo='

$Log = Join-Path $env:TEMP ("cim-bootstrap-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $Log -Force | Out-Null
function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Pass([string]$Text) { Write-Host "PASS $Text" -ForegroundColor Green }
function Invoke-Native([string]$File,[string[]]$Arguments) {
    # Windows PowerShell 5.1 converts every line written by a native program to
    # stderr into a PowerShell error record. With ErrorActionPreference=Stop,
    # harmless progress output (for example uv's "downloading ..." message)
    # terminates the script before the native process can return its real exit code.
    # Temporarily use Continue for the native call, then decide success strictly
    # from LASTEXITCODE.
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        # Merge native stderr into stdout and render each item as ordinary console
        # text. Windows PowerShell 5.1 otherwise decorates harmless stderr output
        # as NativeCommandError even when the process exits successfully.
        & $File @Arguments 2>&1 | ForEach-Object {
            Write-Host $_.ToString()
        }
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    if ($code -ne 0) { throw "$File exited with code $code. Arguments: $($Arguments -join ' ')" }
}
function Get-Distros {
    $lines = & wsl.exe --list --quiet 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    @($lines | ForEach-Object { ($_ -replace "`0", '').Trim() } | Where-Object { $_ })
}
function Invoke-Wsl([string]$User,[string[]]$Arguments) {
    Invoke-Native 'wsl.exe' (@('-d',$Distro,'-u',$User,'--') + $Arguments)
}
function Install-EmbeddedScript([string]$Name,[string]$Base64) {
    $remote = "/tmp/sussex-cim-bootstrap/$Name"
    $command = "install -d -m 0755 /tmp/sussex-cim-bootstrap; printf '%s' '$Base64' | base64 --decode > '$remote'; chmod 0755 '$remote'"
    Invoke-Wsl 'root' @('bash','-lc',$command)
    return $remote
}
function Download-UbuntuRootfs {
    $cache = Join-Path $env:LOCALAPPDATA 'SussexWSL\cache'
    $rootfs = Join-Path $cache 'ubuntu-noble-wsl-amd64.rootfs.tar.gz'
    $sums = Join-Path $cache 'SHA256SUMS'
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    $sources = @(
        @('https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz','https://cloud-images.ubuntu.com/wsl/noble/current/SHA256SUMS'),
        @('https://cloud-images.ubuntu.com/wsl/releases/24.04/current/ubuntu-noble-wsl-amd64-24.04lts.rootfs.tar.gz','https://cloud-images.ubuntu.com/wsl/releases/24.04/current/SHA256SUMS')
    )
    $selected = $null
    foreach ($source in $sources) {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $source[0] -OutFile $rootfs
            Invoke-WebRequest -UseBasicParsing -Uri $source[1] -OutFile $sums
            $selected = $source[0]; break
        } catch { Write-Warning "Download source failed: $($_.Exception.Message)" }
    }
    if (-not $selected) { throw 'Could not download the official Ubuntu WSL rootfs and checksums.' }
    $leaf = Split-Path $selected -Leaf
    $line = Get-Content $sums | Where-Object { $_ -match [regex]::Escape($leaf) } | Select-Object -First 1
    if (-not $line) { throw "Checksum entry not found for $leaf." }
    $expected = (($line -split '\s+')[0]).ToUpperInvariant()
    $actual = (Get-FileHash -Algorithm SHA256 $rootfs).Hash.ToUpperInvariant()
    if ($actual -ne $expected) { Remove-Item $rootfs -Force; throw 'Ubuntu rootfs checksum mismatch.' }
    Write-Pass 'Ubuntu rootfs SHA-256 checksum is valid'
    return $rootfs
}

try {
    Write-Step 'Checking Windows and WSL'
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) { throw 'wsl.exe is unavailable.' }
    $distros = Get-Distros
    if ($distros -notcontains $Distro) {
        Write-Step 'Importing Ubuntu 24.04 for the current Windows user'
        $rootfs = Download-UbuntuRootfs
        New-Item -ItemType Directory -Path $DistroRoot -Force | Out-Null
        try { Invoke-Native 'wsl.exe' @('--import',$Distro,$DistroRoot,$rootfs,'--version','2') }
        catch { if ((Get-Distros) -notcontains $Distro) { Remove-Item $DistroRoot -Recurse -Force -ErrorAction SilentlyContinue }; throw }
    }
    Write-Pass "$Distro is registered"

    $LinuxUser = (($env:USERNAME.ToLowerInvariant() -replace '[^a-z0-9_-]','') -replace '^[^a-z]+','u')
    if (-not $LinuxUser) { $LinuxUser = 'student' }

    Write-Step 'Installing modular bootstrap helpers'
    $prepare = Install-EmbeddedScript 'prepare-distro.sh' $EmbeddedPrepareDistro
    $gpu = Install-EmbeddedScript 'check-gpu.sh' $EmbeddedCheckGpu
    $uvInstaller = Install-EmbeddedScript 'install-uv.sh' $EmbeddedInstallUv
    $cudaInstaller = Install-EmbeddedScript 'install-cuda-toolkit.sh' $EmbeddedInstallCudaToolkitScript
    $projectCreator = Install-EmbeddedScript 'create-project.sh' $EmbeddedCreateProject

    Write-Step "Preparing Ubuntu and Linux user $LinuxUser"
    Invoke-Wsl 'root' @('bash',$prepare,$LinuxUser)
    Write-Pass "Linux user $LinuxUser is ready"

    if ($InstallCudaToolkit) {
        Write-Step 'Installing optional CUDA compiler toolkit'
        Invoke-Wsl 'root' @('bash',$cudaInstaller)
    }

    Write-Step 'Checking NVIDIA GPU access from WSL'
    Invoke-Wsl $LinuxUser @('bash',$gpu)
    Write-Pass 'NVIDIA GPU is visible inside WSL'

    Write-Step "Installing uv $UvVersion"
    Invoke-Wsl $LinuxUser @('bash',$uvInstaller,$UvVersion)
    Write-Pass 'uv is installed'

    $bad = @($ExtraPackages | Where-Object { $_ -notmatch '^[A-Za-z0-9_.-]+([<>=!~][0-9A-Za-z.*+!<>=~-]+)?$' })
    if ($bad.Count) { throw "Unsupported ExtraPackages value: $($bad -join ', ')" }
    $project = "/home/$LinuxUser/projects/$Name"
    $force = if ($ForceRecreateProject) { 'true' } else { 'false' }
    Write-Step "Creating project $project"
    $projectArgs = @('bash',$projectCreator,$project,$PythonVersion,$TorchChannel,$TorchSpec,$TorchvisionSpec,$force) + $ExtraPackages
    Invoke-Wsl $LinuxUser $projectArgs
    Write-Pass 'PyTorch executed a CUDA operation'

    $windowsProjectPath = "\\wsl.localhost\$Distro\home\$LinuxUser\projects\$Name"
    Write-Host "`nProject: $windowsProjectPath" -ForegroundColor Yellow
    if (-not $SkipLaunch) {
        try {
            # Launch the Windows VS Code CLI from PowerShell. Do not invoke Code.exe
            # from Linux, because newly imported WSL distributions can temporarily
            # lack the WSLInterop binfmt registration and report Exec format error.
            $codeCommand = Get-Command 'code.cmd' -ErrorAction SilentlyContinue
            if (-not $codeCommand) { $codeCommand = Get-Command 'code.exe' -ErrorAction SilentlyContinue }
            if (-not $codeCommand) {
                $machineCode = Join-Path $env:ProgramFiles 'Microsoft VS Code\bin\code.cmd'
                $userCode = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\bin\code.cmd'
                if (Test-Path -LiteralPath $machineCode) { $codePath = $machineCode }
                elseif (Test-Path -LiteralPath $userCode) { $codePath = $userCode }
                else { throw 'The Windows VS Code command-line launcher was not found.' }
            } else {
                $codePath = $codeCommand.Source
            }
            & $codePath '--remote' "wsl+$Distro" $project
            if ($LASTEXITCODE -ne 0) { throw "VS Code exited with code $LASTEXITCODE." }
        }
        catch {
            Write-Warning "Setup succeeded, but VS Code could not be launched automatically: $($_.Exception.Message)"
            Write-Host 'Open VS Code, install the WSL extension, then use: WSL: Connect to WSL using Distro.' -ForegroundColor Yellow
            Write-Host "Project path: $windowsProjectPath" -ForegroundColor Yellow
        }
    }
    Write-Host "`nSUCCESS. Transcript: $Log" -ForegroundColor Green
} catch {
    Write-Host "`nFAILED: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Transcript: $Log" -ForegroundColor Yellow
    exit 1
} finally { try { Stop-Transcript | Out-Null } catch {} }
