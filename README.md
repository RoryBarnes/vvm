<p align="center">
  <img width = "250" src="docs/VPLanetLogo.png"/>
</p>

<h1 align="center">VVM: Virtual VPLanet Machine</h1>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-purple.svg"></a>
  <a href="https://VirtualPlanetaryLaboratory.github.io/vplanet/conduct.html">
    <img src="https://img.shields.io/badge/Code%20of-Conduct-7d93c7.svg">
  </a>
  <br>
  <img src="https://img.shields.io/badge/Platforms-Linux_|%20macOS-darkgreen.svg?style=flat">
  <img src="https://img.shields.io/badge/Docker-22.04--based-blue.svg?style=flat">
  <img src="https://img.shields.io/badge/Python-3.11-orange.svg">
</p>

An isolated Docker container for the complete [VPLanet](https://github.com/VirtualPlanetaryLaboratory/vplanet) development ecosystem. VVM packages all 9 repositories into a single, reproducible environment where code changes cannot affect the host filesystem. Designed for safe, long-running AI-assisted coding sessions and multi-agent workflows.

## Quick Start

```bash
vvm
```

That's it. On first run, VVM builds the container image, clones all 9 repositories, compiles VPLanet, and installs all Python packages. Subsequent runs pull the latest code and drop you into a ready-to-use shell.

## Installation

### macOS

VVM requires Docker and a Docker runtime. On macOS, [Colima](https://github.com/abiosoft/colima) provides a lightweight Docker daemon.

**1. Install Docker CLI and Colima via MacPorts:**

```bash
sudo port install docker colima
```

Or via Homebrew:

```bash
brew install docker colima
```

**2. Start Colima:**

```bash
colima start --cpu 9 --memory 8
```

Adjust `--cpu` to one less than your total core count. Colima runs a minimal Linux VM that provides the Docker daemon. It starts in seconds and uses minimal resources when idle.

**3. Install VVM:**

```bash
git clone https://github.com/VirtualPlanetaryLaboratory/vvm.git
cd vvm
chmod +x vvm
sudo ln -sf "$(pwd)/vvm" /opt/local/bin/vvm
```

If using Homebrew, link to `/usr/local/bin/vvm` instead.

**4. Load your SSH key and launch:**

```bash
ssh-add ~/.ssh/id_ed25519
vvm
```

The SSH key is needed for cloning private repositories. VVM forwards your SSH agent into the container so you can also push commits from inside.

### Linux

On Linux, Docker Engine provides the daemon natively. No VM is needed.

**1. Install Docker Engine:**

Follow the official instructions for your distribution at [docs.docker.com/engine/install](https://docs.docker.com/engine/install/).

On Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker $USER
```

Log out and back in for the group change to take effect.

**2. Install VVM:**

```bash
git clone https://github.com/VirtualPlanetaryLaboratory/vvm.git
cd vvm
chmod +x vvm
sudo ln -sf "$(pwd)/vvm" /usr/local/bin/vvm
```

**3. Load your SSH key and launch:**

```bash
ssh-add ~/.ssh/id_ed25519
vvm
```

## Usage

### Starting VVM

```bash
vvm                   # Start an interactive shell inside the container
vvm pytest            # Run a command inside the container
vvm --build           # Force rebuild the container image, then start
vvm --status          # Show whether image, volume, and container exist
vvm --destroy         # Remove the workspace volume (deletes all repo data)
vvm --help            # Show usage information
```

When VVM starts, the entrypoint script:

1. Pulls the latest code from GitHub for each repository
2. Compiles the VPLanet C binary with `-O3` optimizations
3. Installs all Python packages in editable mode
4. Drops into an interactive bash shell at `/workspace`

### Inside the Container

The workspace at `/workspace` contains all 9 repositories:

```
/workspace/
  vplanet-private/    # VPLanet C source and Python package (branch: v3.0)
  vplot/              # Plotting package for VPLanet output
  vspace/             # Parameter sweep generator
  bigplanet/          # HDF5 compression and analysis
  multi-planet/       # Multi-core simulation runner
  alabi/              # Machine learning posterior inference
  vplanet_inference/  # Interface for Bayesian inference
  MaxLEV/             # Maximum likelihood estimator
  vplanet/            # Public VPLanet (reference copy)
```

The native VPLanet binary is on PATH at `/workspace/vplanet-private/bin/vplanet`. Standard development commands work as expected:

```bash
vplanet -v                            # Check VPLanet version
cd /workspace/vspace && pytest        # Run vspace tests
cd /workspace/bigplanet && pytest     # Run bigplanet tests
git status                            # Check repo state
git commit -m "Fix bug"               # Commit changes
git push                              # Push to GitHub
```

### Persistence

Repositories persist in a Docker named volume (`vvm-workspace`) across container restarts. Your cloned repos, local commits, and branch checkouts survive between sessions. Only `vvm --destroy` removes the volume.

The container itself is ephemeral (`--rm`). No container state persists outside the volume.

### Branch Management

VVM clones the default branch for each repository on first run (see `repos.conf`). You can switch branches freely inside the container:

```bash
cd /workspace/vplanet-private
git checkout ClimaGrid
```

On subsequent starts, VVM pulls the branch you are currently on. If you have switched away from the default branch, VVM skips the pull and prints a message.

## Configuration

### repos.conf

The `repos.conf` file defines which repositories VVM manages. Each line specifies a repository name, GitHub URL, default branch, and install method:

```
name|url|branch|install_method
```

**Install methods:**

| Method | Behavior |
|--------|----------|
| `c_and_pip` | Compile C binary with `make opt`, then `pip install -e . --no-deps` |
| `pip_no_deps` | `pip install -e . --no-deps` (dependencies in Dockerfile) |
| `pip_editable` | `pip install -e .` (standalone package, resolves its own deps) |
| `scripts_only` | Add to `PYTHONPATH` and `PATH` only |
| `reference` | Clone for reference, do not install |

Order matters: repositories are cloned and installed in the order listed.

### Resource Allocation

VVM allocates N-1 CPU cores to the container, where N is the host's total core count. Memory is managed by Colima on macOS (set via `colima start --memory`) or by Docker Engine on Linux.

## Output

VVM prints a startup summary showing the environment state:

```
==========================================
  VVM - Virtual VPLanet Machine
==========================================

[vvm] Syncing repositories...
[vvm] Updating vplanet-private...
[vvm] Updating vplot...
...
[vvm] All repositories synced.
[vvm] Building vplanet C binary...
[vvm] vplanet binary ready: /workspace/vplanet-private/bin/vplanet
[vvm] Installing Python packages...
...

==========================================
  Environment Ready
==========================================
  Python:    Python 3.11.x
  GCC:       gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
  vplanet:   /workspace/vplanet-private/bin/vplanet
  Workspace: /workspace
  Cores:     9
==========================================
```

## Troubleshooting

**Docker daemon is not running (macOS):**

```bash
colima start --cpu 9 --memory 8
```

**Docker daemon is not running (Linux):**

```bash
sudo systemctl start docker
```

**Private repo clone fails:**

Ensure your SSH key is loaded: `ssh-add ~/.ssh/id_ed25519`. Verify with `ssh -T git@github.com`.

**Pull skipped for a repository:**

This means you have local commits that have diverged from the remote. VVM uses `--ff-only` to avoid data loss. Resolve manually with `git pull --rebase` inside the container.

**Image rebuild needed after editing repos.conf:**

VVM detects changes to `Dockerfile`, `entrypoint.sh`, and `repos.conf` and rebuilds automatically. To force a full rebuild: `vvm --build`.

**Starting fresh:**

```bash
vvm --destroy    # Remove all cloned repos
vvm              # Reclone everything from GitHub
```
