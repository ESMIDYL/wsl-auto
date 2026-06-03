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

$ErrorActionPreference = "Continue"

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
        $result = wsl -d $Distro -- echo "OK" 2>$null
        return [bool]($result -match "OK")
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
    Write-Check "wsl --install completed" ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 1 -or $LASTEXITCODE -eq -1) | Out-Null

    Write-Host "  Setting WSL default version to 2..." -ForegroundColor Yellow
    wsl --set-default-version 2
    Write-Check "Default version set to 2" ($LASTEXITCODE -eq 0) | Out-Null

    Write-Host "  Installing Ubuntu-24.04 (this may take a few minutes)..." -ForegroundColor Yellow
    wsl --install -d Ubuntu-24.04 --no-launch
    if ($LASTEXITCODE -ne 0) {
        # Check if it failed because it already exists (that's fine)
        $checkAgain = Confirm-DistroInstalled "Ubuntu-24.04"
        if ($checkAgain) {
            Write-Check "Ubuntu-24.04 already installed" $true | Out-Null
        } else {
            Write-Host "  ERROR: Failed to install Ubuntu-24.04 (exit code $LASTEXITCODE)" -ForegroundColor Red
            return
        }
    } else {
        Write-Check "Ubuntu-24.04 downloaded" $true | Out-Null
    }

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
    Write-Host "  Once done, type 'exit' and run this command AGAIN" -ForegroundColor Yellow
    Write-Host "  to continue with DNS, Docker, and Kiro setup." -ForegroundColor Yellow
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

# Enable passwordless sudo for this setup session (avoids repeated password prompts)
Write-Host "  Enabling passwordless sudo for setup..." -ForegroundColor Yellow
$wslUser = (wsl -d Ubuntu-24.04 -- whoami) 2>$null | Out-String
$wslUser = $wslUser.Trim()
wsl -d Ubuntu-24.04 --user root -- bash -c "echo '$wslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/temp-setup && chmod 440 /etc/sudoers.d/temp-setup" 2>&1 | Out-Null
Write-Check "Passwordless sudo enabled for $wslUser" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Setting /etc/resolv.conf (Ericsson DNS)..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/resolv.conf; echo nameserver 193.181.14.10 > /etc/resolv.conf; echo nameserver 193.181.14.11 >> /etc/resolv.conf; echo nameserver 8.8.8.8 >> /etc/resolv.conf" 2>&1 | Out-Null
Write-Check "resolv.conf configured" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Setting /etc/wsl.conf (with boot command for DNS)..." -ForegroundColor Yellow
# Use a boot command to force resolv.conf on every WSL start - this is the most reliable approach
# because systemd-resolved recreates the symlink on boot even when masked
$wslConfContent = "[network]`ngenerateResolvConf=false`n[boot]`nsystemd=true`ncommand=/bin/bash -c 'rm -f /etc/resolv.conf && echo nameserver 193.181.14.10 > /etc/resolv.conf && echo nameserver 193.181.14.11 >> /etc/resolv.conf && echo nameserver 8.8.8.8 >> /etc/resolv.conf'`n"
$wslConfBytes = [System.Text.Encoding]::UTF8.GetBytes($wslConfContent.Replace("`r`n", "`n"))
$wslConfB64 = [Convert]::ToBase64String($wslConfBytes)
wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/wsl.conf && echo $wslConfB64 | base64 -d > /etc/wsl.conf" 2>&1 | Out-Null
Write-Check "wsl.conf configured (with boot DNS command)" ($LASTEXITCODE -eq 0) | Out-Null

# Verify wsl.conf was written correctly
$wslConfCheck = wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/wsl.conf 2>/dev/null'
Write-Host "  wsl.conf content:" -ForegroundColor DarkGray
Write-Host "  $wslConfCheck" -ForegroundColor DarkGray

Write-Host "  Disabling systemd-resolved (prevents DNS override)..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 --user root -- bash -c "systemctl stop systemd-resolved 2>/dev/null; systemctl disable systemd-resolved 2>/dev/null; systemctl mask systemd-resolved 2>/dev/null; rm -f /run/systemd/resolve/stub-resolv.conf 2>/dev/null; rm -f /etc/resolv.conf" 2>&1 | Out-Null
Write-Check "systemd-resolved disabled and masked" ($LASTEXITCODE -eq 0) | Out-Null

# Write resolv.conf now (before restart) using the proven method
Write-Host "  Writing resolv.conf before restart..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/resolv.conf; echo nameserver 193.181.14.10 > /etc/resolv.conf; echo nameserver 193.181.14.11 >> /etc/resolv.conf; echo nameserver 8.8.8.8 >> /etc/resolv.conf" 2>&1 | Out-Null

Write-Host "  Restarting WSL to apply wsl.conf changes..." -ForegroundColor Yellow
wsl --terminate Ubuntu-24.04 2>&1 | Out-Null
Start-Sleep -Seconds 6

# The boot command in wsl.conf should have created resolv.conf on startup
Write-Host "  Verifying resolv.conf after restart..." -ForegroundColor Yellow
$postRestartResolv = wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/resolv.conf 2>/dev/null'
if ($postRestartResolv -notmatch "193.181.14.10") {
    Write-Host "  Boot command didn't write resolv.conf - writing manually..." -ForegroundColor Yellow
    wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/resolv.conf; echo nameserver 193.181.14.10 > /etc/resolv.conf; echo nameserver 193.181.14.11 >> /etc/resolv.conf; echo nameserver 8.8.8.8 >> /etc/resolv.conf" 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    $postRestartResolv = wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/resolv.conf 2>/dev/null'
}

$resolvOk = [bool]($postRestartResolv -match "193.181.14.10")
Write-Check "resolv.conf verified after restart" $resolvOk | Out-Null
if (-not $resolvOk) {
    Write-Host "  WARNING: resolv.conf still not correct after restart." -ForegroundColor Yellow
    Write-Host "  Content: '$postRestartResolv'" -ForegroundColor DarkGray
    $linkCheck = wsl -d Ubuntu-24.04 -- bash -c 'ls -la /etc/resolv.conf 2>&1'
    Write-Host "  File info: $linkCheck" -ForegroundColor DarkGray
}

# ============================================================
# PHASE 4: Install Docker Engine (optional)
# ============================================================
$installDocker = Read-Host "  Would you like to install Docker? (Y/N)"
if ($installDocker -eq 'Y' -or $installDocker -eq 'y') {

Write-Step "Phase 4: Installing Docker Engine"

# Ensure DNS is solid before we start
Write-Host "  Ensuring resolv.conf exists and is correct..." -ForegroundColor Yellow

# First, make sure systemd-resolved isn't running and fighting us
wsl -d Ubuntu-24.04 --user root -- bash -c "systemctl stop systemd-resolved 2>/dev/null; systemctl mask systemd-resolved 2>/dev/null; true" 2>&1 | Out-Null

# Force-remove any symlink or stale file and recreate using simple echo (proven to work)
wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/resolv.conf; echo nameserver 193.181.14.10 > /etc/resolv.conf; echo nameserver 193.181.14.11 >> /etc/resolv.conf; echo nameserver 8.8.8.8 >> /etc/resolv.conf"

# Verify it was written
$resolveCheck = wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/resolv.conf 2>/dev/null'
if ($resolveCheck -match "193.181.14.10") {
    Write-Check "resolv.conf written correctly" $true | Out-Null
} else {
    Write-Host "  WARNING: resolv.conf may not have been written. Content: $resolveCheck" -ForegroundColor Yellow
    Write-Check "resolv.conf write" $false | Out-Null
}

Start-Sleep -Seconds 2

# Use getent/nslookup instead of ping (ICMP is often blocked on corporate networks)
Write-Host "  Verifying DNS resolution works..." -ForegroundColor Yellow
$dnsRetries = 0
$dnsOk = $false
while ($dnsRetries -lt 5 -and -not $dnsOk) {
    # Try DNS resolution via getent (doesn't need ICMP), then nslookup, then dig
    $dnsResult = wsl -d Ubuntu-24.04 -- bash -c 'getent hosts download.docker.com > /dev/null 2>&1 && echo OK || (nslookup download.docker.com 193.181.14.10 > /dev/null 2>&1 && echo OK || (host download.docker.com 193.181.14.10 > /dev/null 2>&1 && echo OK || echo FAIL))'
    if ($dnsResult -match "OK") {
        $dnsOk = $true
    } else {
        $dnsRetries++
        Write-Host "  DNS not resolving, retrying ($dnsRetries/5)..." -ForegroundColor Yellow
        # On retry, also try forcing the nameserver directly in case resolv.conf isn't being read
        if ($dnsRetries -ge 3) {
            Write-Host "  Trying direct DNS query to 8.8.8.8..." -ForegroundColor Yellow
            $directDns = wsl -d Ubuntu-24.04 -- bash -c 'nslookup download.docker.com 8.8.8.8 > /dev/null 2>&1 && echo OK || echo FAIL'
            if ($directDns -match "OK") {
                Write-Host "  Google DNS (8.8.8.8) works! The Ericsson DNS may be unreachable." -ForegroundColor Yellow
                Write-Host "  Updating resolv.conf to prioritize 8.8.8.8..." -ForegroundColor Yellow
                wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/resolv.conf; echo nameserver 8.8.8.8 > /etc/resolv.conf; echo nameserver 193.181.14.10 >> /etc/resolv.conf; echo nameserver 193.181.14.11 >> /etc/resolv.conf"
                $dnsOk = $true
            }
        }
        Start-Sleep -Seconds 3
    }
}

# If DNS resolution works, also check HTTP connectivity
if ($dnsOk) {
    Write-Check "DNS resolves download.docker.com" $true | Out-Null
    Write-Host "  Checking HTTPS connectivity to download.docker.com..." -ForegroundColor Yellow
    $httpResult = wsl -d Ubuntu-24.04 -- bash -c 'curl -fsSL --connect-timeout 10 -o /dev/null -w "%{http_code}" https://download.docker.com/linux/ubuntu/gpg 2>/dev/null'
    if ($httpResult -match "200") {
        Write-Check "HTTPS connectivity to download.docker.com" $true | Out-Null
    } else {
        Write-Host "  WARNING: DNS works but HTTPS returned code: $httpResult" -ForegroundColor Yellow
        Write-Host "  Continuing anyway - apt may still work via proxy..." -ForegroundColor Yellow
    }
} else {
    Write-Check "DNS resolves download.docker.com" $false | Out-Null
    Write-Host ""
    Write-Host "  ERROR: Cannot resolve download.docker.com" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Diagnostics:" -ForegroundColor Yellow
    $diagResolv = wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/resolv.conf 2>&1'
    Write-Host "    /etc/resolv.conf content:" -ForegroundColor DarkGray
    Write-Host "    $diagResolv" -ForegroundColor DarkGray
    $diagNs = wsl -d Ubuntu-24.04 -- bash -c 'nslookup download.docker.com 8.8.8.8 2>&1'
    Write-Host "    nslookup (via 8.8.8.8):" -ForegroundColor DarkGray
    Write-Host "    $diagNs" -ForegroundColor DarkGray
    $diagNs2 = wsl -d Ubuntu-24.04 -- bash -c 'nslookup download.docker.com 193.181.14.10 2>&1'
    Write-Host "    nslookup (via Ericsson DNS):" -ForegroundColor DarkGray
    Write-Host "    $diagNs2" -ForegroundColor DarkGray
    $diagRoute = wsl -d Ubuntu-24.04 -- bash -c 'ip route show default 2>&1'
    Write-Host "    Default route:" -ForegroundColor DarkGray
    Write-Host "    $diagRoute" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Possible fixes:" -ForegroundColor Yellow
    Write-Host "    - Make sure you are connected to the Ericsson network (VPN/office)" -ForegroundColor White
    Write-Host "    - Run: wsl --shutdown  (from PowerShell), then run this script again" -ForegroundColor White
    Write-Host "    - If on VPN, your Windows DNS may need to forward to 193.181.14.10" -ForegroundColor White
    Write-Host "    - Check if your Windows firewall is blocking WSL network traffic" -ForegroundColor White
    Write-Host ""
    $continueAnyway = Read-Host "  Try to continue anyway? (Y/N)"
    if ($continueAnyway -ne 'Y' -and $continueAnyway -ne 'y') {
        return
    }
    Write-Host "  Continuing despite DNS failure..." -ForegroundColor Yellow
}

Write-Host "  Removing conflicting packages..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove -y $pkg 2>/dev/null; done; true'
Write-Check "Conflicting packages removed" $true | Out-Null

Write-Host "  Updating package list..." -ForegroundColor Yellow
$aptResult = wsl -d Ubuntu-24.04 -- bash -c 'sudo apt-get update -qq 2>&1 && echo SUCCESS || echo FAILED'
$aptOk = [bool]($aptResult -match "SUCCESS")
Write-Check "apt-get update" $aptOk | Out-Null
if (-not $aptOk) {
    Write-Host "  ERROR: apt-get update failed. Output:" -ForegroundColor Red
    Write-Host "  $aptResult" -ForegroundColor DarkGray
    return
}

Write-Host "  Installing prerequisites..." -ForegroundColor Yellow
$preReqResult = wsl -d Ubuntu-24.04 -- bash -c 'sudo apt-get install -y ca-certificates curl gnupg 2>&1 && echo SUCCESS || echo FAILED'
$preReqOk = [bool]($preReqResult -match "SUCCESS")
Write-Check "ca-certificates, curl, gnupg installed" $preReqOk | Out-Null
if (-not $preReqOk) {
    Write-Host "  ERROR: Failed to install prerequisites. Output:" -ForegroundColor Red
    Write-Host "  $preReqResult" -ForegroundColor DarkGray
    return
}

Write-Host "  Adding Docker GPG key..." -ForegroundColor Yellow
$gpgScript = 'sudo install -m 0755 -d /etc/apt/keyrings && sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc && sudo chmod a+r /etc/apt/keyrings/docker.asc && echo SUCCESS || echo FAILED'
$gpgB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($gpgScript))
$gpgResult = wsl -d Ubuntu-24.04 -- bash -c "echo $gpgB64 | base64 -d | bash"
$gpgOk = [bool]($gpgResult -match "SUCCESS")
Write-Check "Docker GPG key added" $gpgOk | Out-Null
if (-not $gpgOk) {
    Write-Host "  ERROR: Failed to add Docker GPG key. Check network connectivity." -ForegroundColor Red
    Write-Host "  Output: $gpgResult" -ForegroundColor DarkGray
    return
}

Write-Host "  Adding Docker repository..." -ForegroundColor Yellow
$repoScript = 'echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && echo SUCCESS || echo FAILED'
$repoB64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($repoScript))
$repoResult = wsl -d Ubuntu-24.04 -- bash -c "echo $repoB64 | base64 -d | bash"
$repoOk = [bool]($repoResult -match "SUCCESS")
Write-Check "Docker repository added" $repoOk | Out-Null
if (-not $repoOk) {
    Write-Host "  ERROR: Failed to add Docker repo." -ForegroundColor Red
    return
}

Write-Host "  Updating package list with Docker repo..." -ForegroundColor Yellow
$aptResult2 = wsl -d Ubuntu-24.04 -- bash -c 'sudo apt-get update -qq 2>&1 && echo SUCCESS || echo FAILED'
$aptOk2 = [bool]($aptResult2 -match "SUCCESS")
Write-Check "apt-get update (with Docker repo)" $aptOk2 | Out-Null
if (-not $aptOk2) {
    Write-Host "  ERROR: apt-get update failed after adding Docker repo. Output:" -ForegroundColor Red
    Write-Host "  $aptResult2" -ForegroundColor DarkGray
    return
}

Write-Host "  Installing Docker packages (this may take a few minutes)..." -ForegroundColor Yellow
$dockerInstResult = wsl -d Ubuntu-24.04 -- bash -c 'sudo DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>&1 && echo SUCCESS || echo FAILED'
$dockerInstOk = [bool]($dockerInstResult -match "SUCCESS")
Write-Check "Docker packages installed" $dockerInstOk | Out-Null
if (-not $dockerInstOk) {
    Write-Host "  ERROR: Docker package installation failed. Output (last 20 lines):" -ForegroundColor Red
    $lines = $dockerInstResult -split "`n"
    $lines[-20..-1] | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    return
}

Write-Host "  Adding user to docker group..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 --user root -- bash -c "usermod -aG docker $(wsl -d Ubuntu-24.04 -- whoami)"
Write-Check "User added to docker group" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Enabling and starting Docker with systemd..." -ForegroundColor Yellow
# Since systemd=true is set in wsl.conf, use systemctl
$svcResult = wsl -d Ubuntu-24.04 -- bash -c 'sudo systemctl enable docker 2>&1 && sudo systemctl start docker 2>&1 && echo SUCCESS || echo FAILED'
$svcOk = [bool]($svcResult -match "SUCCESS")
if (-not $svcOk) {
    # Fallback to service command if systemd isn't fully booted yet
    Write-Host "  systemctl failed (systemd may not be ready), trying service command..." -ForegroundColor Yellow
    $svcResult2 = wsl -d Ubuntu-24.04 -- bash -c 'sudo service docker start 2>&1 && echo SUCCESS || echo FAILED'
    $svcOk = [bool]($svcResult2 -match "SUCCESS")
}
Write-Check "Docker service started" $svcOk | Out-Null

Write-Host "  Verifying Docker works..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
$dockerVerify = wsl -d Ubuntu-24.04 -- bash -c 'sudo docker version --format "{{.Server.Version}}" 2>/dev/null'
$dockerRunning = [bool]($dockerVerify -match "\d+\.\d+")
Write-Check "Docker daemon responding" $dockerRunning | Out-Null
if (-not $dockerRunning) {
    Write-Host "  WARNING: Docker installed but daemon not responding yet." -ForegroundColor Yellow
    Write-Host "  It should work after a WSL restart: wsl --shutdown" -ForegroundColor Yellow
}

# --- Configure .bashrc and Docker login ---
Write-Host ""
Write-Host "  Now let's set up your .bashrc environment and Docker login." -ForegroundColor Cyan
Write-Host ""
Write-Host "  You'll need your Identity Tokens from:" -ForegroundColor Yellow
Write-Host "    SELI: https://arm.seli.gic.ericsson.se/ui/packages" -ForegroundColor White
Write-Host "    SERO: https://arm.sero.gic.ericsson.se/ui/packages" -ForegroundColor White
Write-Host ""
Write-Host "  How to get your token:" -ForegroundColor Cyan
Write-Host "    1. Go to the URL above and click Login (top right)" -ForegroundColor White
Write-Host "    2. Login with your Ericsson credentials" -ForegroundColor White
Write-Host "    3. Click the dropdown arrow (top right) -> Edit Profile" -ForegroundColor White
Write-Host "    4. Enter your password to unlock your profile" -ForegroundColor White
Write-Host "    5. Click 'Generate An Identity Token'" -ForegroundColor White
Write-Host "    6. Give it a description -> Click Next" -ForegroundColor White
Write-Host "    7. Copy the Reference Token (save it - you can't see it again!)" -ForegroundColor White
Write-Host ""

$signum = Read-Host "  Enter your Ericsson signum (e.g. esmidyl)"
$seroToken = Read-Host "  Enter your SERO Identity Token"
$seliToken = Read-Host "  Enter your SELI Identity Token"

if ($signum -and $seroToken -and $seliToken) {
    Write-Host ""
    Write-Host "  Writing environment config to .bashrc..." -ForegroundColor Yellow

    # Check if already configured
    $alreadyDone = wsl -d Ubuntu-24.04 -- bash -c 'grep -q "Ericsson Environment Configuration" ~/.bashrc && echo "YES" || echo "NO"'
    if ($alreadyDone -match "YES") {
        Write-Host "  .bashrc already has Ericsson config - skipping to avoid duplicates." -ForegroundColor Yellow
        Write-Check ".bashrc already configured" $true | Out-Null
    } else {
        # Build the bashrc block with actual values substituted
        $bashrcBlock = @"

# ============================================================
# Ericsson Environment Configuration
# ============================================================

# Aliases
alias mvnst='mvn clean install -DskipTests'
alias rebase='git pull --rebase origin master'
alias pushmaster='git push origin HEAD:refs/for/master'
alias pushdraft='git push origin HEAD:refs/drafts/master'

# Credentials
export SIGNUM="$signum"
export SERO_TOKEN="$seroToken"
export SELI_TOKEN="$seliToken"

export PATH=/home/`$SIGNUM/bob:`$PATH
export HELM_USER=`$SIGNUM
export KUBECONFIG=/home/`$SIGNUM/.kube/config

export IMAGE_SECRET=armdocker

export K8_NAMESPACE=`$SIGNUM
export K8S_NAMESPACE=`$SIGNUM

export HELM_REPO_API_TOKEN=`$SELI_TOKEN
export HELM_INSTALL_TIMEOUT=5m0s

export ARM_USER=`$SIGNUM
export ARM_TOKEN=`$SELI_TOKEN

export SELI_ARTIFACTORY_REPO_USER=`$SIGNUM
export SELI_ARTIFACTORY_REPO_PASS=`$SELI_TOKEN

export SERO_ARTIFACTORY_REPO_USER=`$SIGNUM
export SERO_ARTIFACTORY_REPO_PASS=`$SERO_TOKEN

# run bob commands to build your project and package a helm chart
bob-pack() {
  bob clean init-dev build image package-local
}

# command to remove docker image by passing the image name
rmi () {
  docker rmi `$(docker images | grep "`$1")
}

# uninstall everything and reset namespace
function reset {
  helm delete `$(helm ls --short --namespace `$K8_NAMESPACE) --namespace `$K8_NAMESPACE
  kubectl delete namespace `$K8_NAMESPACE && kubectl create namespace `$K8_NAMESPACE || kubectl create namespace `$K8_NAMESPACE
  kubectl create secret generic `$IMAGE_SECRET --from-file=.dockerconfigjson=`$HOME/.docker/config.json --type=kubernetes.io/dockerconfigjson --namespace `$K8_NAMESPACE || true
}
"@

        # Encode as base64 to safely pass through PowerShell -> WSL without any quoting/heredoc issues
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($bashrcBlock.Replace("`r`n", "`n"))
        $b64 = [Convert]::ToBase64String($bytes)

        # Decode inside WSL and append to .bashrc
        wsl -d Ubuntu-24.04 -- bash -c "echo $b64 | base64 -d >> ~/.bashrc" 2>&1 | Out-Null
        Write-Check ".bashrc environment configured" ($LASTEXITCODE -eq 0) | Out-Null
    }

    # Docker login using the provided credentials
    Write-Host "  Logging into Ericsson ARM Docker registry..." -ForegroundColor Yellow
    $loginResult = wsl -d Ubuntu-24.04 -- bash -c "echo '$seliToken' | docker login armdocker.rnd.ericsson.se -u $signum --password-stdin 2>&1"
    $loginOk = [bool]($loginResult -match "Login Succeeded")
    Write-Check "Docker login to armdocker.rnd.ericsson.se" $loginOk | Out-Null
    if (-not $loginOk) {
        Write-Host "  WARNING: Docker login failed. Output:" -ForegroundColor Yellow
        Write-Host "  $loginResult" -ForegroundColor DarkGray
        Write-Host "  You can retry later with: docker login armdocker.rnd.ericsson.se" -ForegroundColor Yellow
    }

} else {
    Write-Host "  Missing values - skipping .bashrc and Docker login." -ForegroundColor Yellow
    Write-Host "  You can set them up manually later." -ForegroundColor Yellow
}

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

Write-Host "  Verifying DNS before Kiro install..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'ping -c 1 cli.kiro.dev > /dev/null 2>&1' 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  DNS not resolving - re-applying resolv.conf..." -ForegroundColor Yellow
    wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/resolv.conf; echo nameserver 193.181.14.10 > /etc/resolv.conf; echo nameserver 193.181.14.11 >> /etc/resolv.conf; echo nameserver 8.8.8.8 >> /etc/resolv.conf" 2>&1 | Out-Null
    Start-Sleep -Seconds 2
    wsl -d Ubuntu-24.04 -- bash -c 'ping -c 1 cli.kiro.dev > /dev/null 2>&1' 2>$null
}
Write-Check "DNS resolving for cli.kiro.dev" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Installing unzip..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'sudo apt-get install -y -qq unzip' 2>&1 | Out-Null
Write-Check "unzip installed" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host "  Adding ~/.local/bin to PATH..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'grep -q "HOME/.local/bin" ~/.bashrc || echo "export PATH=\"\$HOME/.local/bin:\$PATH\"" >> ~/.bashrc' 2>&1 | Out-Null
Write-Check "PATH updated in .bashrc" ($LASTEXITCODE -eq 0) | Out-Null

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "    Kiro CLI Installation & Setup" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  You'll be dropped into Ubuntu to install and configure Kiro." -ForegroundColor Yellow
Write-Host ""
Write-Host "  The install command will run automatically." -ForegroundColor Yellow
Write-Host "  When prompted:" -ForegroundColor Cyan
Write-Host "    1. Select: 'Use with Pro license'" -ForegroundColor White
Write-Host "    2. Start URL: https://d-9367077c28.awsapps.com/start" -ForegroundColor White
Write-Host "    3. Region: eu-west-1" -ForegroundColor White
Write-Host "    4. Click the browser link to authenticate" -ForegroundColor White
Write-Host "    5. Select the 'SelectMe' or 'KiroProfile' profile" -ForegroundColor White
Write-Host ""
Write-Host "  When finished, type 'exit' to return here." -ForegroundColor Magenta
Write-Host ""
Read-Host "  Press Enter to begin Kiro setup"

# Launch interactive Ubuntu shell - user runs the install command themselves
# This ensures proper TTY for interactive prompts
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Magenta
Write-Host "  Copy and paste this command into Ubuntu:" -ForegroundColor Magenta
Write-Host "" -ForegroundColor White
Write-Host "  curl -fsSL https://cli.kiro.dev/install | bash" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "  Then type 'exit' when setup is complete." -ForegroundColor Magenta
Write-Host "  ============================================" -ForegroundColor Magenta
Write-Host ""
wsl -d Ubuntu-24.04
Write-Check "Kiro CLI setup completed" ($LASTEXITCODE -eq 0) | Out-Null

} else {
    Write-Host ""
    Write-Host "  Skipping Kiro CLI installation." -ForegroundColor DarkGray
}

# ============================================================
# CLEANUP: Remove temporary passwordless sudo
# ============================================================
Write-Host ""
Write-Host "  Removing temporary passwordless sudo..." -ForegroundColor DarkGray
wsl -d Ubuntu-24.04 -- bash -c 'sudo rm -f /etc/sudoers.d/temp-setup' 2>&1 | Out-Null

# ============================================================
# FINAL VERIFICATION
# ============================================================
Write-Step "Final Verification"

$dnsCheck = (wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/resolv.conf') 2>$null | Out-String
$dnsOk = [bool]($dnsCheck -match "193.181.14.10")
if (-not $dnsOk) {
    Write-Host "  DNS missing - re-applying resolv.conf..." -ForegroundColor Yellow
    wsl -d Ubuntu-24.04 --user root -- bash -c "rm -f /etc/resolv.conf; echo nameserver 193.181.14.10 > /etc/resolv.conf; echo nameserver 193.181.14.11 >> /etc/resolv.conf; echo nameserver 8.8.8.8 >> /etc/resolv.conf" 2>&1 | Out-Null
    $dnsCheck = (wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/resolv.conf') 2>$null | Out-String
    $dnsOk = [bool]($dnsCheck -match "193.181.14.10")
}
Write-Check "DNS: 193.181.14.10 present in resolv.conf" $dnsOk | Out-Null

$confCheck = (wsl -d Ubuntu-24.04 -- bash -c 'cat /etc/wsl.conf') 2>$null | Out-String
$confOk = [bool]($confCheck -match "generateResolvConf=false")
Write-Check "wsl.conf: generateResolvConf=false" $confOk | Out-Null

$systemdOk = [bool]($confCheck -match "systemd=true")
Write-Check "wsl.conf: systemd=true" $systemdOk | Out-Null

$kiroCheck = (wsl -d Ubuntu-24.04 -- bash -c 'export PATH="$HOME/.local/bin:$PATH" && which kiro 2>/dev/null') 2>$null | Out-String
$kiroOk = [bool]($kiroCheck -match "kiro")
if ($kiroOk) {
    Write-Check "Kiro CLI installed" $true | Out-Null
}

$dockerCheck = (wsl -d Ubuntu-24.04 -- bash -c 'docker --version 2>/dev/null') 2>$null | Out-String
$dockerOk = [bool]($dockerCheck -match "Docker")
if ($dockerOk) {
    Write-Check "Docker installed" $true | Out-Null
}

Write-Host ""
Write-Host "  Testing network: ping gerrit-gamma.gic.ericsson.se..." -ForegroundColor Yellow
wsl -d Ubuntu-24.04 -- bash -c 'ping -c 3 gerrit-gamma.gic.ericsson.se' 2>$null
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
