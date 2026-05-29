#!/bin/bash
# ============================================================
#   macOS Setup Script (Ericsson)
#   Configures DNS and installs Kiro CLI
#   by Dylan Smith
#
#   Usage:
#     curl -fsSL https://raw.githubusercontent.com/dylansmithkilbeggan-rgb/wsl-auto/main/macsetup/setup-mac.sh | bash
# ============================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================================
# HELPER FUNCTIONS
# ============================================================

write_step() {
    echo ""
    echo -e "${CYAN}[$(date '+%H:%M:%S')] === $1 ===${NC}"
    echo ""
}

write_check() {
    if [ "$2" = "true" ]; then
        echo -e "  ${GREEN}[PASS]${NC} $1"
    else
        echo -e "  ${RED}[FAIL]${NC} $1"
    fi
}

# ============================================================
# PRE-FLIGHT CHECKS
# ============================================================
write_step "Pre-flight Checks"

# Check we're on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo -e "  ${RED}ERROR: This script is for macOS only.${NC}"
    echo "  For Windows, use the PowerShell script instead."
    exit 1
fi
write_check "Running on macOS" "true"

# Check for curl
if command -v curl &> /dev/null; then
    write_check "curl available" "true"
else
    write_check "curl available" "false"
    echo -e "  ${RED}ERROR: curl is required. Install Xcode Command Line Tools:${NC}"
    echo "    xcode-select --install"
    exit 1
fi

# Check for bash
if command -v bash &> /dev/null; then
    write_check "bash available" "true"
else
    write_check "bash available" "false"
    exit 1
fi

# ============================================================
# BANNER
# ============================================================
echo ""
echo -e "  ${CYAN}============================================${NC}"
echo -e "  ${CYAN}  macOS Ericsson Dev Setup${NC}"
echo -e "  ${NC}  Ericsson Internal${NC}"
echo -e "  ${CYAN}============================================${NC}"
echo ""

# ============================================================
# PHASE 1: Configure DNS
# ============================================================
write_step "Phase 1: Configuring Ericsson DNS"

echo -e "  ${YELLOW}This will set your DNS servers to:${NC}"
echo "    - 193.181.14.10 (Ericsson primary)"
echo "    - 193.181.14.11 (Ericsson secondary)"
echo "    - 8.8.8.8 (Google fallback)"
echo ""

# Detect the active network interface
active_service=$(networksetup -listallnetworkservices | grep -v "asterisk" | while read service; do
    if networksetup -getinfo "$service" 2>/dev/null | grep -q "IP address: [0-9]"; then
        echo "$service"
        break
    fi
done)

if [ -z "$active_service" ]; then
    # Fallback to Wi-Fi
    active_service="Wi-Fi"
fi

echo -e "  ${YELLOW}Detected network service: ${NC}$active_service"
echo ""
read -p "  Set DNS on '$active_service'? (Y/N): " dns_response

if [[ "$dns_response" == "Y" || "$dns_response" == "y" ]]; then
    sudo networksetup -setdnsservers "$active_service" 193.181.14.10 193.181.14.11 8.8.8.8
    write_check "DNS configured on $active_service" "true"

    # Flush DNS cache
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder 2>/dev/null || true
    write_check "DNS cache flushed" "true"
else
    echo -e "  ${YELLOW}Skipping DNS configuration.${NC}"
fi

# ============================================================
# PHASE 2: Test connectivity
# ============================================================
write_step "Phase 2: Testing Ericsson Network Connectivity"

echo -e "  ${YELLOW}Pinging gerrit-gamma.gic.ericsson.se...${NC}"
if ping -c 3 gerrit-gamma.gic.ericsson.se &> /dev/null; then
    write_check "Ping gerrit-gamma.gic.ericsson.se" "true"
else
    write_check "Ping gerrit-gamma.gic.ericsson.se" "false"
    echo -e "  ${YELLOW}  Make sure you're connected to the Ericsson network.${NC}"
fi

# ============================================================
# PHASE 3: Install Docker (optional)
# ============================================================
echo ""
read -p "  Would you like to install Docker? (Y/N): " docker_response

if [[ "$docker_response" == "Y" || "$docker_response" == "y" ]]; then

    write_step "Phase 3: Installing Docker"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        write_check "Docker already installed ($(docker --version))" "true"
    else
        # Check if Homebrew is available
        if command -v brew &> /dev/null; then
            echo -e "  ${YELLOW}Installing Docker via Homebrew...${NC}"
            brew install --cask docker
            write_check "Docker Desktop installed" "true"
            echo ""
            echo -e "  ${YELLOW}Please open Docker Desktop from Applications to complete setup.${NC}"
            echo -e "  ${YELLOW}Docker Desktop must be running for the docker command to work.${NC}"
        else
            echo -e "  ${YELLOW}Homebrew not found. Install Docker Desktop manually:${NC}"
            echo "    https://docs.docker.com/desktop/install/mac-install/"
            write_check "Docker installed" "false"
        fi
    fi

    echo ""
    echo -e "  ${YELLOW}To login to Ericsson ARM registry:${NC}"
    echo "    Make sure ARM_USER and ARM_TOKEN are exported in your shell config"
    echo "    Then run: docker login armdocker.rnd.ericsson.se -u \$ARM_USER -p \$ARM_TOKEN"
    echo ""

else
    echo -e "  ${YELLOW}  Skipping Docker installation.${NC}"
fi

# ============================================================
# PHASE 4: Install Kiro CLI (optional)
# ============================================================
echo ""
read -p "  Would you like to install Kiro CLI? (Y/N): " kiro_response

if [[ "$kiro_response" == "Y" || "$kiro_response" == "y" ]]; then

    write_step "Phase 4: Installing Kiro CLI"

    # Ensure unzip is available (should be by default on macOS)
    if command -v unzip &> /dev/null; then
        write_check "unzip available" "true"
    else
        echo -e "  ${YELLOW}Installing unzip via Homebrew...${NC}"
        brew install unzip
    fi

    # Ensure ~/.local/bin is on PATH
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo -e "  ${YELLOW}Adding ~/.local/bin to PATH...${NC}"

        # Detect shell config file
        if [ -f "$HOME/.zshrc" ]; then
            shell_rc="$HOME/.zshrc"
        elif [ -f "$HOME/.bashrc" ]; then
            shell_rc="$HOME/.bashrc"
        else
            shell_rc="$HOME/.zshrc"
        fi

        if ! grep -q 'HOME/.local/bin' "$shell_rc" 2>/dev/null; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            write_check "PATH updated in $shell_rc" "true"
        fi
        export PATH="$HOME/.local/bin:$PATH"
    else
        write_check "~/.local/bin already on PATH" "true"
    fi

    # Install Kiro CLI
    echo ""
    echo -e "  ${MAGENTA}>>> WHEN PROMPTED: <<<${NC}"
    echo "    - License: Select 'Pro license'"
    echo "    - Start URL: https://d-9367077c28.awsapps.com/start"
    echo "    - Region: eu-west-1"
    echo ""
    read -p "  Press Enter to start Kiro CLI installation..."

    curl -fsSL https://cli.kiro.dev/install | bash

    # Verify
    if command -v kiro &> /dev/null || [ -f "$HOME/.local/bin/kiro" ]; then
        write_check "Kiro CLI installed" "true"
    else
        write_check "Kiro CLI installed" "false"
        echo -e "  ${YELLOW}  You may need to restart your terminal for PATH changes to take effect.${NC}"
    fi

else
    echo -e "  ${YELLOW}  Skipping Kiro CLI installation.${NC}"
fi

# ============================================================
# DONE
# ============================================================
echo ""
echo -e "  ${GREEN}============================================${NC}"
echo -e "  ${GREEN}  SETUP COMPLETE!${NC}"
echo -e "  ${GREEN}============================================${NC}"
echo ""
echo -e "  ${CYAN}You're all set. Happy coding!${NC}"
echo ""
