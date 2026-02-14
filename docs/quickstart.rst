Quick Start
===========

Once Docker and ``VVM`` are installed (see :doc:`install`),
start the container with a single command:

.. code-block:: bash

    vvm

On first run, ``VVM``:

1. Builds the Docker image (Ubuntu 22.04, Python 3.11, all scientific
   dependencies)
2. Creates a persistent Docker volume for the workspace
3. Clones all public repositories from GitHub
4. Compiles the ``VPLanet`` C binary with ``-O3`` optimizations
5. Installs all Python packages in editable mode
6. Drops into an interactive bash shell at ``/workspace``

Subsequent runs pull the latest code, recompile if needed, and verify
package installations. This typically takes under a minute.

Example Session
---------------

.. code-block:: bash

    $ vvm
    ==========================================
      VVM - Virtual VPLanet Machine
    ==========================================

    [vvm] Syncing repositories...
    [vvm] Updating vplanet...
    [vvm] Updating vplot...
    ...
    [vvm] All repositories synced.
    [vvm] Building vplanet from public repository...
    [vvm] vplanet binary ready: /workspace/vplanet/bin/vplanet
    [vvm] Installing Python packages...
    ...

    ==========================================
      Environment Ready
    ==========================================
      Python:    Python 3.11.x
      GCC:       gcc (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0
      vplanet:   /workspace/vplanet/bin/vplanet
      Workspace: /workspace
      Cores:     9
    ==========================================

    vplanet@vvm:/workspace$

From here you can run simulations, execute tests, commit code, and push
to GitHub. The host filesystem is completely isolated.

Running a Command
-----------------

To run a single command inside the container without entering an interactive
shell:

.. code-block:: bash

    vvm pytest /workspace/vspace/tests/ -x

This starts the container, runs the command, and exits.
