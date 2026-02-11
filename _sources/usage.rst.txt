Usage
=====

Commands
--------

Run ``VVM`` from the host with the following options:

.. code-block:: bash

    vvm                   # Start an interactive shell
    vvm <command>         # Run a command inside the container
    vvm --build           # Force rebuild the image, then start
    vvm --status          # Show image, volume, and container state
    vvm --destroy         # Remove the workspace volume
    vvm --help            # Show usage information

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

VS Code
-------

``VVM`` includes a Dev Containers configuration for
`VS Code <https://code.visualstudio.com/>`_. There are two ways to use
VS Code with ``VVM``:

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

Option B requires the
`Dev Containers <https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers>`_
extension. It installs the GitHub CLI inside the container and forwards
your host credentials, so ``gh auth login`` on the host is sufficient.

Both options install the Python and C/C++ extensions inside the container
automatically.

Claude Code (Optional)
----------------------

`Claude Code <https://docs.anthropic.com/en/docs/claude-code>`_ is an
AI coding assistant that can be installed inside the container for
interactive development sessions. It is not included in the default image.

To install Claude Code manually inside a running container:

.. code-block:: bash

    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    npm install -g @anthropic-ai/claude-code

To persist the configuration across container restarts, create a symlink
before first use:

.. code-block:: bash

    mkdir -p /workspace/.claude
    ln -sfn /workspace/.claude /root/.claude
    claude

Claude Code prompts for your Anthropic API key interactively. The key and
configuration persist in the workspace volume at ``/workspace/.claude/``,
so you only need to authenticate once.

To start Claude Code in a specific repository:

.. code-block:: bash

    cd /workspace/vplanet
    claude

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

Log out and back in for this to take effect.

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
