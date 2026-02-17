#!/bin/sh
# install_vvm.sh - Install VVM and its host dependencies.
#
# Detects the operating system and package manager, installs Docker and
# the GitHub CLI, clones the VVM repository, creates a symlink so that
# "vvm" is available on PATH, and adds the VVM bin directory to the
# user's shell configuration.
#
# Usage:
#   sh install_vvm.sh [-y|--yes] [--claude]

set -e

VVM_REPO="https://github.com/RoryBarnes/vvm.git"
INSTALL_CLAUDE=false
ASSUME_YES=false

# ---------------------------------------------------------------------------
fnPrintError() { echo "ERROR: $1" >&2; }

# ---------------------------------------------------------------------------
# fnParseArguments: Handle command-line flags
# ---------------------------------------------------------------------------
fnParseArguments() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -y|--yes)
                ASSUME_YES=true
                ;;
            --claude)
                INSTALL_CLAUDE=true
                ;;
            *)
                fnPrintError "Unknown option: $1"
                echo "Usage: sh install_vvm.sh [-y|--yes] [--claude]" >&2
                exit 1
                ;;
        esac
        shift
    done
}

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
    if [ "${ASSUME_YES}" = true ]; then
        sudo port -N install docker colima gh
    else
        sudo port install docker colima gh
    fi
}

# ---------------------------------------------------------------------------
# fnInstallHomebrew: Install Docker, Colima, and gh via Homebrew
# ---------------------------------------------------------------------------
fnInstallHomebrew() {
    echo "[install] Installing docker, colima, and gh via Homebrew..."
    if [ "${ASSUME_YES}" = true ]; then
        NONINTERACTIVE=1 brew install docker colima gh
    else
        brew install docker colima gh
    fi
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
    sBinDir="$1"

    if [ -x "./vvm" ] && [ -f "./Dockerfile" ]; then
        echo "[install] Already inside the VVM repository."
    elif [ -d "vvm" ]; then
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

    fnConfigureShellPath "$(pwd)/bin"
}

# ---------------------------------------------------------------------------
# fnConfigureShellPath: Add the VVM bin directory to the user's shell PATH
# Arguments: sBinDirectory
# ---------------------------------------------------------------------------
fnConfigureShellPath() {
    sBinDirectory="$1"
    sRcFile=""

    sShellName="$(basename "${SHELL:-/bin/sh}")"

    case "${sShellName}" in
        zsh)
            sRcFile="${HOME}/.zshrc"
            ;;
        bash)
            if [ "$(uname -s)" = "Darwin" ]; then
                sRcFile="${HOME}/.bash_profile"
            else
                sRcFile="${HOME}/.bashrc"
            fi
            ;;
        fish)
            sRcFile="${HOME}/.config/fish/config.fish"
            ;;
        *)
            sRcFile="${HOME}/.profile"
            ;;
    esac

    if [ -z "${sRcFile}" ]; then
        echo "[install] Could not determine shell config file. Skipping PATH setup."
        echo "[install] Add this to your shell config manually:"
        echo "  export PATH=\"${sBinDirectory}:\$PATH\""
        return
    fi

    if [ "${sShellName}" = "fish" ]; then
        sExportLine="set -gx PATH ${sBinDirectory} \$PATH"
    else
        sExportLine="export PATH=\"${sBinDirectory}:\$PATH\""
    fi

    if [ -f "${sRcFile}" ] && grep -qF "${sBinDirectory}" "${sRcFile}" 2>/dev/null; then
        echo "[install] PATH already configured in ${sRcFile}."
        return
    fi

    {
        echo ""
        echo "# Added by VVM installer"
        echo "${sExportLine}"
    } >> "${sRcFile}"
    echo "[install] Added ${sBinDirectory} to PATH in ${sRcFile}."
    echo "[install] Open a new terminal or run: . ${sRcFile}"
}

# ---------------------------------------------------------------------------
# fnEnableClaude: Mark VVM to include Claude Code in the Docker image
# ---------------------------------------------------------------------------
fnEnableClaude() {
    sVvmDirectory="$1"

    touch "${sVvmDirectory}/.claude_enabled"
    echo "[install] Claude Code will be included in the Docker image."
    echo "[install] The image will be built with Claude Code on first 'vvm' run."
}

# ===========================================================================
# Main
# ===========================================================================
fnParseArguments "$@"
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

if [ "${INSTALL_CLAUDE}" = true ]; then
    fnEnableClaude "$(pwd)"
fi

if [ "${PLATFORM}" = "Darwin" ]; then
    echo "[install] After starting Colima, run 'vvm' to launch the Virtual VPLanet Machine."
else
    echo "[install] After logging out and back in, run 'vvm' to launch the Virtual VPLanet Machine."
fi
