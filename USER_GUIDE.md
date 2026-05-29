# WSL & Kiro Automated Setup Guide

**Ericsson Internal** | Dylan Smith | 2026

---

## What This Does

This script automatically sets up your development environment in one command:

- ✅ Installs WSL2 (Windows Subsystem for Linux)
- ✅ Installs Ubuntu 24.04
- ✅ Configures Ericsson DNS servers
- ✅ Configures wsl.conf (systemd + DNS persistence)
- ✅ Installs Docker Engine (optional)
- ✅ Installs Kiro CLI (optional)

---

## Windows Setup

### Prerequisites

- Windows 10 version 2004 or higher (Build 19041+)
- Internet connection
- Connected to Ericsson network (for DNS verification)

### Step 1: Open PowerShell as Administrator

1. Right-click the **Start button**
2. Click **"Terminal (Admin)"** or **"Windows PowerShell (Admin)"**
3. Click **Yes** on the UAC prompt

### Step 2: Run the Command

Copy and paste this entire command into PowerShell and press Enter:

```powershell
irm https://raw.githubusercontent.com/ESMIDYL/wsl-auto/main/wsl-auto/setup-wsl.ps1 | iex
```

### Step 3: Follow the Prompts

The script will guide you through each step:

| Prompt | What to do |
|--------|-----------|
| **Restart now? (Y/N)** | Type `Y` — a reboot is required after enabling WSL features |
| **After reboot** | Open PowerShell as Admin again and run the same command |
| **Press Enter to launch Ubuntu** | Press Enter, then create your user account |
| **Ubuntu username** | Use your **Ericsson signum** (e.g. `esmidyl`) |
| **Ubuntu password** | Set a password you'll remember |
| **Install Docker? (Y/N)** | Type `Y` if you need Docker |
| **Install Kiro CLI? (Y/N)** | Type `Y` if you need Kiro |
| **Kiro License** | Select **Pro license** |
| **Kiro Start URL** | `https://d-9367077c28.awsapps.com/start` |
| **Kiro Region** | `eu-west-1` |

### Step 4: Verify

The script runs verification checks at the end. You should see all `[PASS]` results:

```
  [PASS] DNS: 193.181.14.10 present in resolv.conf
  [PASS] wsl.conf: generateResolvConf=false
  [PASS] wsl.conf: systemd=true
  [PASS] Docker installed
  [PASS] Kiro CLI installed
  [PASS] Ping gerrit-gamma.gic.ericsson.se
```

### How Many Times Do I Run It?

| Machine State | Runs needed |
|--------------|-------------|
| Fresh install (no WSL) | 2 (run → reboot → run again) |
| WSL already enabled | 1 |
| Everything already installed | 1 (skips to verification) |

The script detects what's already done and picks up where it left off.

---

## Mac Setup

### Step 1: Open Terminal

Press `Cmd + Space`, type **Terminal**, press Enter.

### Step 2: Run the Command

```bash
curl -fsSL https://raw.githubusercontent.com/ESMIDYL/wsl-auto/main/macsetup/setup-mac.sh | bash
```

### Step 3: Follow the Prompts

| Prompt | What to do |
|--------|-----------|
| **Set DNS? (Y/N)** | Type `Y` to configure Ericsson DNS |
| **Install Docker? (Y/N)** | Type `Y` if you need Docker (installs via Homebrew) |
| **Install Kiro CLI? (Y/N)** | Type `Y` if you need Kiro |
| **Kiro License** | Select **Pro license** |
| **Kiro Start URL** | `https://d-9367077c28.awsapps.com/start` |
| **Kiro Region** | `eu-west-1` |

---

## After Setup

### Launching Ubuntu (Windows)

- **Start Menu** → search "Ubuntu 24.04"
- Or in any terminal: `wsl -d Ubuntu-24.04`

### Docker Login (Both platforms)

Make sure `ARM_USER` and `ARM_TOKEN` are set in your `.bashrc`, then run:

```bash
docker login armdocker.rnd.ericsson.se -u $ARM_USER -p $ARM_TOKEN
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Not running as Administrator" | Right-click PowerShell → Run as Admin |
| "Windows version too old" | Run Windows Update |
| Ping fails at the end | Make sure you're on the Ericsson network/VPN |
| 404 error on the command | Check you have internet access |
| Docker won't start after reboot | Run `sudo service docker start` in Ubuntu |

---

## Support

If you run into issues, contact Dylan Smith or raise an issue on the GitHub repo:
https://github.com/ESMIDYL/wsl-auto
