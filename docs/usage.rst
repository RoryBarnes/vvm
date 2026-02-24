Usage
=====

Commands
--------

Run ``VVM`` from the host with the following options:

.. code-block:: bash

    vvm                   # Start an interactive shell
    vvm <command>         # Run a command inside the container
    vvm --build           # Force rebuild the image, then start
    vvm --claude          # Enable Claude Code and rebuild
    vvm --status          # Show image, volume, and container state
    vvm --destroy         # Remove the workspace volume
    vvm --help            # Show usage information
    connect_vvm           # Open a new shell in the running container

Workspace Layout
----------------

Inside the container, ``/workspace`` contains all repositories:

.. code-block:: bash

    /workspace/
      vplanet/              # VPLanet C source and Python package
      vplot/                # Plotting package for VPLanet output
      vspace/               # Parameter sweep generator
      bigplanet/            # HDF5 compression and analysis
      multi-planet/         # Multi-core simulation runner
      alabi/                # Machine learning posterior inference
      vplanet_inference/    # Interface for Bayesian inference
      MaxLEV/               # Maximum likelihood estimator
      vplanet-private/      # Development branch (if authenticated)

The native ``VPLanet`` binary is on ``PATH`` at
``/workspace/vplanet/bin/vplanet``. If ``vplanet-private`` is available,
``VVM`` builds from it instead and the binary path updates accordingly.

Standard development commands work as expected:

.. code-block:: bash

    vplanet -v                                  # Check VPLanet version
    cd /workspace/vplanet && make test          # Run VPLanet tests
    cd /workspace/vspace && pytest tests/ -x    # Run vspace tests
    git status                                  # Check repo state

Persistence
-----------

Repositories persist in a Docker named volume (``vvm-workspace``) across
container restarts. *Cloned repos, local commits, and branch checkouts all
survive between sessions.* Only ``vvm --destroy`` removes the volume.

Git configuration (``~/.gitconfig``) is also stored on the volume, so
``git config --global user.name`` and ``git config --global user.email``
only need to be set once.

The container itself is ephemeral (``--rm``). No container state persists
outside the volume.

Branch Management
-----------------

``VVM`` clones the default branch for each repository on first run (see
``repos.conf``). You can switch branches freely inside the container:

.. code-block:: bash

    cd /workspace/vplanet
    git checkout my-feature-branch

On subsequent starts, ``VVM`` pulls the branch you are currently on. If you
have switched away from the default branch, ``VVM`` skips the pull and
prints a message.

.. _git-workflow:

Git Workflow
------------

``VVM`` supports two workflows depending on your level of access.

**Standard workflow (fork and pull request):**

Most collaborators should fork the public repository on GitHub and submit
changes via pull request. Inside the container:

.. code-block:: bash

    cd /workspace/vplanet
    git remote add myfork https://github.com/YOUR_USERNAME/vplanet.git
    git checkout -b my-feature
    # ... make changes ...
    git commit -m "Description of changes"
    git push myfork my-feature

Then open a pull request on GitHub from your fork's branch to the main
repository. This is the standard open-source contribution workflow and
requires no special permissions.

.. tip::

   You only need to add your fork as a remote once. The remote persists
   in the workspace volume across container restarts.

**Direct push (vplanet-private developers only):**

Authorized collaborators with write access to ``vplanet-private`` can push
directly:

.. code-block:: bash

    cd /workspace/vplanet-private
    git push origin my-branch

This requires GitHub CLI authentication (see :ref:`private-repo-access`).
Direct push access is being deprecated in favor of the fork and pull
request workflow described above.

repos.conf
----------

The ``repos.conf`` file defines which repositories ``VVM`` manages. Each
line specifies a repository name, GitHub URL, default branch, and install
method, separated by pipes:

.. code-block:: bash

    name|url|branch|install_method

Lines beginning with ``#`` are comments.

**Install methods:**

.. list-table::
   :header-rows: 1
   :widths: 20 60

   * - Method
     - Behavior
   * - ``c_and_pip``
     - Compile C binary with ``make opt``, then ``pip install -e . --no-deps``
   * - ``pip_no_deps``
     - ``pip install -e . --no-deps`` (dependencies provided by Dockerfile)
   * - ``pip_editable``
     - ``pip install -e .`` (standalone package, resolves its own deps)
   * - ``scripts_only``
     - Add to ``PYTHONPATH`` and ``PATH`` only
   * - ``reference``
     - Clone for reference, do not install

Order matters: repositories are cloned and installed in the order listed.

To add a new repository, append a line to ``repos.conf`` and run
``vvm --build`` to rebuild the image.

Display Forwarding
------------------

``VVM`` forwards the host's X11 display into the container so that
interactive matplotlib figures (``plt.show()``) render in a window on
your desktop.

**macOS** requires `XQuartz <https://www.xquartz.org/>`_ and ``xhost``,
both of which the installer sets up automatically. After installing
XQuartz, a one-time configuration step is needed:

1. Open **XQuartz > Settings > Security** and enable
   *Allow connections from network clients*.
2. Log out of macOS and log back in (required once for the TCP listener
   to activate).

When you run ``vvm``, it automatically:

- Starts XQuartz if it is not already running.
- Runs ``xhost +`` to allow the container to connect.
- Sets ``DISPLAY=host.docker.internal:0`` inside the container.

.. note::

   If you installed XQuartz via MacPorts, you also need the ``xhost``
   package (``sudo port install xhost``). The Homebrew XQuartz cask
   includes ``xhost`` already.

**Linux** uses the host's native X11 server. No extra setup is needed;
``VVM`` grants container access via ``xhost``, passes through
``$DISPLAY``, and mounts the X11 socket automatically.

**Troubleshooting display issues:**

If ``plt.show()`` does not open a window, check the following:

1. Verify XQuartz (macOS) or an X server (Linux) is running.
2. Confirm the one-time XQuartz configuration above was completed,
   including the logout/login step.
3. Ensure the matplotlib backend is set to ``TkAgg``, not ``Agg``:

   .. code-block:: python

      import matplotlib
      print(matplotlib.get_backend())  # Should print "TkAgg"

   If it prints ``agg``, set the backend before importing pyplot:

   .. code-block:: python

      import matplotlib
      matplotlib.use("TkAgg")
      import matplotlib.pyplot as plt

**Viewing standalone files:**

The container includes lightweight X11 viewers for opening images and
documents directly:

.. code-block:: bash

    eog figure.png          # GNOME image viewer (PNG, JPG, TIFF, etc.)
    feh plot.png            # Lightweight image viewer
    evince paper.pdf        # PDF and PostScript viewer

These viewers forward to the host display via X11, just like
``plt.show()``. If you prefer to view files on the host instead, use
``vvm_pull`` to copy them out of the container first.

.. _installed-packages:

Installed Packages
------------------

The ``VVM`` container image is built on Ubuntu 22.04 and includes the
following pre-installed software.

**System tools:**

.. list-table::
   :widths: 25 55
   :header-rows: 0

   * - ``gcc``, ``g++``, ``make``
     - C/C++ compilation toolchain
   * - ``git``
     - Version control
   * - ``valgrind``, ``lcov``
     - Memory analysis and code coverage
   * - ``nano``, ``vim``
     - Text editors
   * - ``curl``, ``gnupg``
     - Network and security utilities
   * - ``gosu``, ``sudo``
     - Privilege management

**X11 viewers (display via host):**

.. list-table::
   :widths: 25 55
   :header-rows: 0

   * - ``eog``
     - GNOME image viewer (PNG, JPG, TIFF, BMP, SVG)
   * - ``evince``
     - PDF and PostScript viewer
   * - ``feh``
     - Lightweight command-line image viewer

**LaTeX (for matplotlib TeX rendering):**

.. list-table::
   :widths: 25 55
   :header-rows: 0

   * - ``texlive-latex-base``
     - Core LaTeX distribution
   * - ``texlive-latex-extra``
     - Additional LaTeX packages
   * - ``texlive-fonts-recommended``
     - Standard fonts
   * - ``cm-super``, ``dvipng``
     - Computer Modern fonts and DVI-to-PNG conversion

**Python 3.11 packages:**

.. list-table::
   :widths: 30 50
   :header-rows: 0

   * - ``numpy``, ``scipy``
     - Numerical computing
   * - ``matplotlib``, ``seaborn``
     - Plotting and visualization
   * - ``astropy``
     - Astronomy utilities
   * - ``h5py``, ``pandas``
     - Data storage and analysis
   * - ``emcee``, ``dynesty``
     - MCMC and nested sampling
   * - ``george``
     - Gaussian process regression
   * - ``corner``
     - Corner plots for posterior distributions
   * - ``scikit-learn``, ``scikit-optimize``
     - Machine learning and optimization
   * - ``SALib``
     - Sensitivity analysis (Sobol indices)
   * - ``pytest``, ``pytest-cov``
     - Testing framework and coverage
   * - ``tqdm``
     - Progress bars
   * - ``setuptools``, ``wheel``, ``pybind11``
     - Build tools

All Python packages are pre-installed in a single layer so that editable
installs of the workspace repositories (``pip install -e . --no-deps``)
resolve instantly without downloading dependencies.

VS Code
-------

``VVM`` includes a Dev Containers configuration for
`VS Code <https://code.visualstudio.com/>`_. Both options below require
the `Dev Containers <https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers>`_
extension. Install it from the Extensions panel (``Cmd+Shift+X`` on
macOS, ``Ctrl+Shift+X`` on Linux) by searching for "Dev Containers."

**Option A: Attach to a running container**

1. Start the container from the terminal: ``vvm``
2. In VS Code, press ``Cmd+Shift+P`` (macOS) or ``Ctrl+Shift+P`` (Linux)
3. Select **Dev Containers: Attach to Running Container**
4. Choose the ``vvm`` container
5. VS Code opens a new window connected to ``/workspace``

**Option B: Open directly in Dev Container**

1. Open the ``vvm`` repository folder in VS Code
2. VS Code detects ``.devcontainer/devcontainer.json`` and prompts to
   reopen in container
3. Click **Reopen in Container**
4. VS Code builds the image, starts the container, runs the entrypoint,
   and connects automatically

Option B installs the GitHub CLI inside the container and forwards
your host credentials, so ``gh auth login`` on the host is sufficient.

Both options install the Python and C/C++ extensions inside the container
automatically.

**macOS with Colima:** The ``installVvm.sh`` script creates a symlink
from ``/var/run/docker.sock`` to the Colima socket so that VS Code (and
other tools) can find Docker at the standard path. If VS Code cannot
find the container, verify the symlink exists:

.. code-block:: bash

    ls -l /var/run/docker.sock
    # Should point to ~/.colima/default/docker.sock

If the symlink is missing, recreate it:

.. code-block:: bash

    sudo ln -sf ~/.colima/default/docker.sock /var/run/docker.sock

Claude Code (Optional)
----------------------

`Claude Code <https://docs.anthropic.com/en/docs/claude-code>`_ is an
AI coding assistant that can be installed inside the container for
interactive development sessions. It is not included in the default image.

**Option 1: Enable after installation**

If ``VVM`` is already installed, enable Claude Code and rebuild the image
in one step:

.. code-block:: bash

    vvm --claude

This creates a ``.claude_enabled`` marker, rebuilds the base image, and
layers the ``Dockerfile.claude`` overlay on top (adding Node.js and Claude
Code). On subsequent runs, ``vvm`` and ``vvm --build`` will include the
Claude overlay automatically.

**Option 2: Enable during initial setup**

Pass ``--claude`` when running the installer:

.. code-block:: bash

    sh installVvm.sh --claude

The Claude Code overlay will be built automatically on the first ``vvm``
run.

**Option 3: Install manually inside the container**

If you prefer not to bake Claude Code into the image, you can install it
at any time inside a running container. Note that manual installs do not
persist across container restarts (use ``vvm --claude`` instead for a
permanent solution). The container runs as the ``vplanet`` user, so use
``sudo``:

.. code-block:: bash

    sudo bash -c 'curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
        && apt-get install -y nodejs \
        && npm install -g @anthropic-ai/claude-code'

``VVM`` automatically persists Claude Code's configuration in the
workspace volume at ``/workspace/.claude/``, so you only need to
authenticate once. To start Claude Code in a specific repository:

.. code-block:: bash

    cd /workspace/vplanet
    claude

Container Utilities
-------------------

``VVM`` includes utility scripts for working with the container.

**connect_vvm** opens a new shell session in an already-running container.
This is useful when you want a second terminal inside the container while
your first session is still active:

.. code-block:: bash

    connect_vvm

The ``connect_vvm`` command is available on the host after running the
installer. It is equivalent to ``docker exec -it -u vplanet vvm bash``.

**checkIsolation.sh** verifies that the container's filesystem is
isolated from the host. It is located in the ``vplanet`` user's home
directory and can be run inside the container:

.. code-block:: bash

    ~/checkIsolation.sh

The script checks for host bind mounts, listening network ports, Docker
socket access, and privileged mode. All checks should pass under normal
``VVM`` operation.

Tab Completion
~~~~~~~~~~~~~~

``VVM`` provides tab-completion for ``vvm``, ``vvm_push``, and ``vvm_pull``
in bash and zsh. The installer configures completion automatically.

**vvm** completes command-line flags (``--build``, ``--status``,
``--destroy``, ``--help``).

**vvm_pull** completes container paths for all positional arguments.
Pressing ``Tab`` queries the running container's ``/workspace`` directory
and offers matching entries. Directories appear with a trailing ``/`` so
you can continue typing into subdirectories. If the container is not
running, completion silently falls back to local file paths.

**vvm_push** completes local file paths for source arguments (the default
behavior) and switches to container path completion for the destination
argument. Once at least one source path has been typed, subsequent
arguments offer container path completion.

Options (``-a``, ``-L``, ``-r``, ``-R``, ``--help``) are completed for
both ``vvm_push`` and ``vvm_pull`` when the current word starts with
``-``.

.. code-block:: bash

    vvm_pull vpl<Tab>
    # Completes to: vplanet/ vplot/ vplanet-private/ ...

    vvm_push results.h5 Max<Tab>
    # Completes to: MaxLEV/

If completions are not working, ensure your shell configuration sources
the completion file. The installer adds a line like this to your shell
RC file:

.. code-block:: bash

    # Added by VVM installer
    [ -f "/path/to/vvm/completions/vvm.bash" ] && . "/path/to/vvm/completions/vvm.bash"

Open a new terminal or source the file manually for the change to take
effect.

Resource Allocation
-------------------

``VVM`` allocates N-1 CPU cores to the container, where N is the host's
total core count. Memory is managed by Colima on macOS (set via
``colima start --memory``) or by Docker Engine on Linux.

Troubleshooting
---------------

This section covers common issues you may encounter. If you are new to
Docker, see the :ref:`what-is-docker` note below.

**Docker daemon is not running (macOS):**

Docker on macOS runs inside a lightweight virtual machine called Colima.
If you see this error, Colima needs to be started:

.. code-block:: bash

    colima start --cpu $(( $(sysctl -n hw.ncpu) - 1 )) --memory 8

You need to run this once after each reboot. Colima stays running in the
background until you shut down your computer.

**Docker daemon is not running (Linux):**

The Docker service needs to be started:

.. code-block:: bash

    sudo systemctl start docker

To make Docker start automatically on boot:

.. code-block:: bash

    sudo systemctl enable docker

**Permission denied when running Docker (Linux):**

Your user account needs to be in the ``docker`` group:

.. code-block:: bash

    sudo usermod -aG docker $USER

Log out and back in for this to take effect. To apply the change in
your current terminal without logging out:

.. code-block:: bash

    newgrp docker

**Repository clone fails:**

If a public repository fails to clone, check your internet connection and
firewall settings. ``VVM`` clones from ``github.com`` via HTTPS, so port
443 must be open.

If ``vplanet-private`` fails to clone, this is expected for users without
access to the private repository. ``VVM`` will continue with the public
``vplanet`` repository instead. If you should have access, see
:ref:`private-repo-access`.

**VPLanet build fails:**

The ``VPLanet`` C binary requires ``gcc`` and ``make``, which are included
in the container image. If the build fails, the most common cause is a
corrupted repository. Try starting fresh:

.. code-block:: bash

    vvm --destroy
    vvm

**Pull skipped for a repository:**

This means you have local commits that have diverged from the remote.
``VVM`` uses ``--ff-only`` pulls to avoid overwriting your work. To update
manually:

.. code-block:: bash

    cd /workspace/vplanet
    git pull --rebase

**Image rebuild needed after editing repos.conf:**

``VVM`` detects changes to ``Dockerfile``, ``entrypoint.sh``, and
``repos.conf`` and rebuilds automatically. To force a full rebuild:
``vvm --build``.

**Container uses too much memory:**

On macOS, Colima's memory limit is set at startup. To increase it:

.. code-block:: bash

    colima stop
    colima start --cpu $(( $(sysctl -n hw.ncpu) - 1 )) --memory 16

On Linux, Docker uses host memory directly. If the container is consuming
too much memory, close other applications or increase your swap space.

**Starting fresh:**

To remove all cloned repositories and start over:

.. code-block:: bash

    vvm --destroy
    vvm

.. _what-is-docker:

.. note:: **What is Docker?**

   Docker is a tool that creates isolated environments called
   "containers." A container is like a lightweight virtual machine: it has
   its own operating system, files, and installed software, completely
   separate from your computer. VVM uses Docker to ensure that everyone
   gets the same development environment regardless of what operating
   system or software versions they have on their own machine. Nothing
   that happens inside the container can affect your computer's files.
