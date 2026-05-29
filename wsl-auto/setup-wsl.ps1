<#
.SYNOPSIS
    Automated WSL2 + Ubuntu-24.04 setup (Ericsson)
.DESCRIPTION
    One-command WSL2 + Ubuntu-24.04 installer with Ericsson DNS config.
    by Dylan Smith.
.USAGE
    From any PowerShell (run as Admin):
    irm https://raw.githubusercontent.com/ESMIDYL/wsl-auto/main/wsl-auto/setup-wsl.ps1 | iex
#>

$ErrorActionPreference = "Stop"

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "[$((Get-Date).ToString('HH:mm:ss'))] === $Message ===" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Check {
    param([string]$Message, [bool]$Pass)
    if ($Pass) {
        Write-Host "  [PASS] $Message" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Message" -ForegroundColor Red
    }
    return $Pass
}

function Confirm-Admin {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return [bool]$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Confirm-WindowsBuild {
    $build = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
    return [bool]($build -ge 19041)
}

function Confirm-FeatureEnabled {
    param([string]$FeatureName)
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        return [bool]($feature.State -eq "Enabled")
    } catch {
        return $false
    }
}

function Confirm-DistroInstalled {
    param([string]$Distro)
    try {
        $list = wsl --list --quiet 2>$null
        if ($null -eq $list) { return $false }
        return [bool]($list -match $Distro)
    } catch {
        return $false
    }
}

# ============================================================
# ADMIN CHECK
# ============================================================
if (-not (Confirm-Admin)) {
    Write-Host ""
    Write-Host "  ERROR: You must run PowerShell as Administrator." -ForegroundColor Red
    Write-Host ""
    Write-Host "  How to:" -ForegroundColor Yellow
    Write-Host "    1. Right-click the Start button" -ForegroundColor White
    Write-Host "    2. Click 'Terminal (Admin)' or 'PowerShell (Admin)'" -ForegroundColor White
    Write-Host "    3. Run the command again" -ForegroundColor White
    Write-Host ""
    return
}

# ============================================================
# BANNER
# ============================================================
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "    WSL2 + Ubuntu-24.04 Automated Setup" -ForegroundColor Cyan
Write-Host "    Ericsson Internal" -ForegroundColor DarkGray
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================
Write-Step "Pre-flight Checks"

$buildOk = Write-Check "Windows Build >= 19041 (WSL2 compatible)" (Confirm-WindowsBuild)
if (-not $buildOk) {
    Write-Host "`n  ERROR: Your Windows version is too old for WSL2." -ForegroundColor Red
    Write-Host "  Please run Windows Update and try again." -ForegroundColor Red
    return
}

Write-Check "Running as Administrator" $true | Out-Null

# ============================================================
# DETECT CURRENT STATE
# ============================================================
Write-Step "Detecting current setup state"

$wslFeatureOn = Confirm-FeatureEnabled "Microsoft-Windows-Subsystem-Linux"
$vmFeatureOn  = Confirm-FeatureEnabled "VirtualMachinePlatform"
$ubuntuInstalled = Confirm-DistroInstalled "Ubuntu-24.04"

Write-Check "WSL Feature enabled" $wslFeatureOn | Out-Null
Write-Check "VirtualMachinePlatform enabled" $vmFeatureOn | Out-Null
Write-Check "Ubuntu-24.04 installed" $ubuntuInstalled | Out-Null

# ============================================================
# PHASE 1: Enable features (if needed)
# ============================================================
if (-not $wslFeatureOn -or -not $vmFeatureOn) {
    Write-Step "Phase 1: Enabling WSL Features"

    if (-not $wslFeatureOn) {
        Write-Host "  Enabling Microsoft-Windows-Subsystem-Linux..." -ForegroundColor Yellow
        dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
            Write-Host "  ERROR: Failed to enable WSL feature (exit code $LASTEXITCODE)" -ForegroundColor Red
            return
        }
        Write-Check "WSL feature enabled" $true | Out-Null
    }

    if (-not $vmFeatureOn) {
        Write-Host "  Enabling VirtualMachinePlatform..." -ForegroundColor Yellow
        dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) {
            Write-Host "  ERROR: Failed to enable VirtualMachinePlatform (exit code $LASTEXITCODE)" -ForegroundColor Red
            return
        }
        Write-Check "VirtualMachinePlatform enabled" $true | Out-Null
    }

    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "    Features enabled! REBOOT REQUIRED." -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  After rebooting, run the SAME COMMAND again." -ForegroundColor Yellow
    Write-Host "  The script will pick up where it left off." -ForegroundColor Yellow
    Write-Host ""

    $response = Read-Host "  Restart now? (Y/N)"
    if ($response -eq 'Y' -or $response -eq 'y') {
        Restart-Computer -Force
    }
    return
}

# ============================================================
# PHASE 2: Install WSL + Ubuntu-24.04
# ============================================================
if (-not $ubuntuInstalled) {
    Write-Step "Phase 2: Installing WSL and Ubuntu-24.04"

    Write-Host "  Running wsl --install..." -ForegroundColor Yellow
    wsl.exe --install --no-launch
    Write-Check "wsl --install completed" ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1) | Out-Null

    Write-Host "  Setting WSL default version to 2..." -ForegroundColor Yellow
    wsl --set-default-version 2
    Write-Check "Default version set to 2" ($LASTEXITCODE -eq 0) | Out-Null

    Write-Host "  Installing Ubuntu-24.04 (this may take a few minutes)..." -ForegroundColor Yellow
    wsl --install -d Ubuntu-24.04 --no-launch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Failed to install Ubuntu-24.04 (exit code $LASTEXITCODE)" -ForegroundColor Red
        return
    }
    Write-Check "Ubuntu-24.04 downloaded" $true | Out-Null

    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host "    Ubuntu-24.04 installed!" -ForegroundColor Green
    Write-Host "  ============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Ubuntu will now launch for first-time setup." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  >>> USE YOUR ERICSSON SIGNUM AS THE USERNAME <<<" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "  Set a password you'll remember." -ForegroundColor Yellow
    Write-Host "  Once done, type 'exit' and the script continues." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "  Press Enter to launch Ubuntu"

    wsl -d Ubuntu-24.04

    # Verify
    $ubuntuInstalled = Confirm-DistroInstalled "Ubuntu-24.04"
    if (-not $ubuntuInstalled) {
        Write-Host "  ERROR: Ubuntu-24.04 not detected after setup. Run the command again." -ForegroundColor Red
        return
    }
    Write-Check "Ubuntu-24.04 registered in WSL" $true | Out-Null
}

# ============================================================
# PHASE 3: Configure DNS and wsl.conf
# ============================================================
Write-Step "Phase 3: Configuring DNS and wsl.conf"

Write-Host "  Setting /etc/resolv.conf (Ericsson DNS)..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c "sudo rm -rf /etc/resolv.conf && echo 'nameserver 193.181.14.10
nameserver 193.181.14.11
nameserver 8.8.8.8' | sudo tee /etc/resolv.conf > /dev/null"
Write-Check "resolv.conf configured" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Setting /etc/wsl.conf..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c "sudo rm -rf /etc/wsl.conf && printf '[network]\ngenerateResolvConf=false\n[boot]\nsystemd=true\n' | sudo tee /etc/wsl.conf > /dev/null"
Write-Check "wsl.conf configured" ($LASTEXITCODE -eq 0) | Out-Null

# ============================================================
# PHASE 4: Install Docker Engine (optional)
# ============================================================
$installDocker = Read-Host "  Would you like to install Docker? (Y/N)"
if ($installDocker -eq 'Y' -or $installDocker -eq 'y') {

Write-Step "Phase 4: Installing Docker Engine"

Write-Host "  Removing conflicting packages..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg 2>/dev/null; done'
Write-Check "Conflicting packages removed" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Adding Docker GPG key and repository..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'sudo apt-get update && sudo apt-get install -y ca-certificates curl && sudo install -m 0755 -d /etc/apt/keyrings && sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && sudo chmod a+r /etc/apt/keyrings/docker.asc'
Write-Check "Docker GPG key installed" ($LASTEXITCODE -eq 0) | Out-Null

wsl -d Ubuntu-24.04 -- bash -c 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null'
Write-Check "Docker repository added" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Installing Docker packages (this may take a few minutes)..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'sudo apt-get update && sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin'
Write-Check "Docker installed" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Adding user to docker group..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'sudo usermod -aG docker $USER'
Write-Check "User added to docker group" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Adding Docker auto-start to .bashrc..." -ForegroundColor Yellow
$dockerAutoStart = @'
if ! grep -q "service docker status" ~/.bashrc; then
printf '\n# Auto-start Docker service in WSL\nif grep -q "microsoft" /proc/version > /dev/null 2>&1; then\n    if service docker status 2>&1 | grep -q "is not running"; then\n        wsl.exe --distribution "${WSL_DISTRO_NAME}" --user root \\\n            --exec /usr/sbin/service docker start > /dev/null 2>&1\n    fi\nfi\n' >> ~/.bashrc
fi
'@
$dockerAutoStart | wsl -d Ubuntu-24.04 -- bash
Write-Check "Docker auto-start added to .bashrc" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Starting Docker service..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c "sudo service docker start"
Write-Check "Docker service started" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host ""
Write-Host "  Docker login to Ericsson ARM registry:" -ForegroundColor Yellow
Write-Host "  Make sure ARM_USER and ARM_TOKEN are exported in your .bashrc" -ForegroundColor Yellow
Write-Host "  Then run: docker login armdocker.rnd.ericsson.se -u \$ARM_USER -p \$ARM_TOKEN" -ForegroundColor White
Write-Host ""

} else {
    Write-Host ""
    Write-Host "  Skipping Docker installation." -ForegroundColor DarkGray
}

# ============================================================
# PHASE 5: Install Kiro CLI (optional)
# ============================================================
$installKiro = Read-Host "  Would you like to install Kiro CLI? (Y/N)"
if ($installKiro -eq 'Y' -or $installKiro -eq 'y') {

Write-Step "Phase 5: Installing Kiro CLI"

Write-Host "  Installing unzip..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c "sudo apt-get install -y unzip"
Write-Check "unzip installed" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Adding ~/.local/bin to PATH..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c "grep -q 'HOME/.local/bin' ~/.bashrc || echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
Write-Check "PATH updated in .bashrc" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Downloading and installing Kiro CLI..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  >>> WHEN PROMPTED: <<<" -ForegroundColor Magenta
Write-Host "    - License: Select 'Pro license'" -ForegroundColor White
Write-Host "    - Start URL: https://d-9367077c28.awsapps.com/start" -ForegroundColor White
Write-Host "    - Region: eu-west-1" -ForegroundColor White
Write-Host ""
Read-Host "  Press Enter to start Kiro CLI installation"

wsl -d Ubuntu-24.04 -- bash -c "export PATH=\"\$HOME/.local/bin:\$PATH\" && curl -fsSL https://cli.kiro.dev/install | bash"
Write-Check "Kiro CLI installer completed" ($LASTEXITCODE -eq 0) | Out-Null

} else {
    Write-Host ""
    Write-Host "  Skipping Kiro CLI installation." -ForegroundColor DarkGray
}

# ============================================================
# FINAL VERIFICATION
# ============================================================
Write-Step "Final Verification"

$dnsCheck = wsl -d Ubuntu-24.04 -- bash -c "cat /etc/resolv.conf" 2>$null
$dnsOk = ($dnsCheck -match "193.181.14.10")
Write-Check "DNS: 193.181.14.10 present in resolv.conf" $dnsOk | Out-Null

$confCheck = wsl -d Ubuntu-24.04 -- bash -c "cat /etc/wsl.conf" 2>$null
$confOk = ($confCheck -match "generateResolvConf=false")
Write-Check "wsl.conf: generateResolvConf=false" $confOk | Out-Null

$systemdOk = ($confCheck -match "systemd=true")
Write-Check "wsl.conf: systemd=true" $systemdOk | Out-Null

$kiroCheck = wsl -d Ubuntu-24.04 -- bash -c "export PATH=\"\$HOME/.local/bin:\$PATH\" && which kiro 2>/dev/null"
$kiroOk = ($LASTEXITCODE -eq 0 -and $kiroCheck -ne "")
if ($kiroOk) {
    Write-Check "Kiro CLI installed" $true | Out-Null
}

$dockerCheck = wsl -d Ubuntu-24.04 -- bash -c "docker --version 2>/dev/null"
$dockerOk = ($LASTEXITCODE -eq 0 -and $dockerCheck -ne "")
if ($dockerOk) {
    Write-Check "Docker installed ($dockerCheck)" $true | Out-Null
}

Write-Host ""
Write-Host "  Testing network: ping gerrit-gamma.gic.ericsson.se..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c "ping -c 3 gerrit-gamma.gic.ericsson.se" 2>$null
$pingOk = ($LASTEXITCODE -eq 0)
Write-Check "Ping gerrit-gamma.gic.ericsson.se" $pingOk | Out-Null

# ============================================================
# DONE
# ============================================================
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Green
Write-Host "    SETUP COMPLETE!" -ForegroundColor Green
Write-Host "  ============================================" -ForegroundColor Green
Write-Host ""
if ($pingOk) {
    Write-Host "  Everything is working. You're good to go!" -ForegroundColor Green
} else {
    Write-Host "  Ping failed - make sure you're on the Ericsson network." -ForegroundColor Yellow
    Write-Host "  DNS config is still saved. It'll work once connected." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Launch Ubuntu anytime:" -ForegroundColor Cyan
Write-Host "    - Start Menu -> Ubuntu 24.04" -ForegroundColor White
Write-Host "    - Or run:  wsl -d Ubuntu-24.04" -ForegroundColor White
Write-Host ""

