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
      vplanet-private/    # VPLanet C source and Python package (branch: v3.0)
      vplot/              # Plotting package for VPLanet output
      vspace/             # Parameter sweep generator
      bigplanet/          # HDF5 compression and analysis
      multi-planet/       # Multi-core simulation runner
      alabi/              # Machine learning posterior inference
      vplanet_inference/  # Interface for Bayesian inference
      MaxLEV/             # Maximum likelihood estimator
      vplanet/            # Public VPLanet (reference copy)

The native ``VPLanet`` binary is on PATH at
``/workspace/vplanet-private/bin/vplanet``. Standard development commands
work as expected:

.. code-block:: bash

    vplanet -v                            # Check VPLanet version
    cd /workspace/vspace && pytest        # Run vspace tests
    git status                            # Check repo state
    git commit -m "Fix bug"               # Commit changes
    git push                              # Push to GitHub

Persistence
-----------

Repositories persist in a Docker named volume (``vvm-workspace``) across
container restarts. Cloned repos, local commits, and branch checkouts all
survive between sessions. Only ``vvm --destroy`` removes the volume.

The container itself is ephemeral (``--rm``). No container state persists
outside the volume.

Branch Management
-----------------

``VVM`` clones the default branch for each repository on first run (see
``repos.conf``). You can switch branches freely inside the container:

.. code-block:: bash

    cd /workspace/vplanet-private
    git checkout ClimaGrid

On subsequent starts, ``VVM`` pulls the branch you are currently on. If you
have switched away from the default branch, ``VVM`` skips the pull and
prints a message.

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

Resource Allocation
-------------------

``VVM`` allocates N-1 CPU cores to the container, where N is the host's
total core count. Memory is managed by Colima on macOS (set via
``colima start --memory``) or by Docker Engine on Linux.

Troubleshooting
---------------

**Docker daemon is not running (macOS):**

.. code-block:: bash

    colima start --cpu 9 --memory 8

**Docker daemon is not running (Linux):**

.. code-block:: bash

    sudo systemctl start docker

**Private repo clone fails:**

Ensure your SSH key is loaded: ``ssh-add ~/.ssh/id_ed25519``. Verify
with ``ssh -T git@github.com``.

**Pull skipped for a repository:**

This means you have local commits that have diverged from the remote.
``VVM`` uses ``--ff-only`` to avoid data loss. Resolve manually with
``git pull --rebase`` inside the container.

**Image rebuild needed after editing repos.conf:**

``VVM`` detects changes to ``Dockerfile``, ``entrypoint.sh``, and
``repos.conf`` and rebuilds automatically. To force a full rebuild:
``vvm --build``.

**Starting fresh:**

.. code-block:: bash

    vvm --destroy
    vvm
