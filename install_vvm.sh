#!/bin/sh
# install_vvm.sh - Install VVM and its host dependencies.
#
# Detects the operating system and package manager, installs Docker and
# the GitHub CLI, clones the VVM repository, and creates a symlink so
# that "vvm" is available on PATH.
#
# Usage:
#   sh install_vvm.sh

set -e

VVM_REPO="https://github.com/RoryBarnes/vvm.git"

# ---------------------------------------------------------------------------
fnPrintError() { echo "ERROR: $1" >&2; }

# ---------------------------------------------------------------------------
# fnDetectPlatform: Set PLATFORM to "Darwin" or "Linux"
# ---------------------------------------------------------------------------
fnDetectPlatform() {
    PLATFORM="$(uname -s)"
    if [ "${PLATFORM}" != "Darwin" ] && [ "${PLATFORM}" != "Linux" ]; then
        fnPrintError "Unsupported platform: ${PLATFORM}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# fnDetectMacPackageManager: Set MAC_PKG to "port", "brew", or exit
# ---------------------------------------------------------------------------
fnDetectMacPackageManager() {
    if command -v port > /dev/null 2>&1; then
        MAC_PKG="port"
    elif command -v brew > /dev/null 2>&1; then
        MAC_PKG="brew"
    else
        fnPrintError "Neither MacPorts nor Homebrew found."
        echo "Install one of:" >&2
        echo "  MacPorts: https://www.macports.org/install.php" >&2
        echo "  Homebrew: https://brew.sh/" >&2
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# fnInstallMacPorts: Install Docker, Colima, and gh via MacPorts
# ---------------------------------------------------------------------------
fnInstallMacPorts() {
    echo "[install] Installing docker, colima, and gh via MacPorts..."
    sudo port install docker colima gh
}

# ---------------------------------------------------------------------------
# fnInstallHomebrew: Install Docker, Colima, and gh via Homebrew
# ---------------------------------------------------------------------------
fnInstallHomebrew() {
    echo "[install] Installing docker, colima, and gh via Homebrew..."
    brew install docker colima gh
}

# ---------------------------------------------------------------------------
# fnInstallDebian: Install Docker Engine and gh on Debian/Ubuntu
# ---------------------------------------------------------------------------
fnInstallDebian() {
    echo "[install] Installing Docker Engine on Debian/Ubuntu..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io

    echo "[install] Installing GitHub CLI..."
    sudo mkdir -p -m 755 /etc/apt/keyrings
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
        https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y gh

    sudo systemctl enable --now docker
    sudo usermod -aG docker "${USER}"
    echo "[install] Log out and back in for Docker group to take effect."
}

# ---------------------------------------------------------------------------
# fnInstallFedora: Install Docker Engine and gh on Fedora/RHEL
# ---------------------------------------------------------------------------
fnInstallFedora() {
    echo "[install] Installing Docker Engine on Fedora/RHEL..."
    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io

    echo "[install] Installing GitHub CLI..."
    sudo dnf install -y 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo \
        https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh

    sudo systemctl enable --now docker
    sudo usermod -aG docker "${USER}"
    echo "[install] Log out and back in for Docker group to take effect."
}

# ---------------------------------------------------------------------------
# fnCloneAndLink: Clone VVM and create the symlink
# ---------------------------------------------------------------------------
fnCloneAndLink() {
    local sBinDir="$1"

    if [ -d "vvm" ]; then
        echo "[install] vvm directory already exists. Skipping clone."
        cd vvm
    else
        echo "[install] Cloning VVM..."
        git clone "${VVM_REPO}"
        cd vvm
    fi
    chmod +x vvm
    echo "[install] Creating symlink at ${sBinDir}/vvm..."
    sudo ln -sf "$(pwd)/vvm" "${sBinDir}/vvm"
}

# ===========================================================================
# Main
# ===========================================================================
fnDetectPlatform
echo "[install] Detected platform: ${PLATFORM}"

if [ "${PLATFORM}" = "Darwin" ]; then
    fnDetectMacPackageManager
    echo "[install] Using package manager: ${MAC_PKG}"
    if [ "${MAC_PKG}" = "port" ]; then
        fnInstallMacPorts
        fnCloneAndLink "/opt/local/bin"
    else
        fnInstallHomebrew
        fnCloneAndLink "$(brew --prefix)/bin"
    fi
    echo ""
    echo "[install] Installation complete."
    echo "[install] Start Colima before first use:"
    CORES=$(sysctl -n hw.ncpu)
    echo "  colima start --cpu $(( CORES - 1 )) --memory 8"

elif [ "${PLATFORM}" = "Linux" ]; then
    if command -v apt-get > /dev/null 2>&1; then
        fnInstallDebian
        fnCloneAndLink "/usr/local/bin"
    elif command -v dnf > /dev/null 2>&1; then
        fnInstallFedora
        fnCloneAndLink "/usr/local/bin"
    else
        fnPrintError "Unsupported Linux distribution."
        echo "VVM requires apt (Debian/Ubuntu) or dnf (Fedora/RHEL)." >&2
        exit 1
    fi
    echo ""
    echo "[install] Installation complete."
fi

echo "[install] Run 'vvm' to start the Virtual VPLanet Machine."
