Installation Guide
==================

``VVM`` requires three tools on the host: **Docker**, a **Docker runtime**,
and the **GitHub CLI** (``gh``). The installation differs between macOS and
Linux because macOS needs a lightweight VM to run Linux containers.

macOS
-----

**1. Install Docker CLI, Colima, and GitHub CLI**

`Colima <https://github.com/abiosoft/colima>`_ provides a lightweight Docker
daemon on macOS. The `GitHub CLI <https://cli.github.com/>`_ manages
authentication securely via your OS keychain (see
`Authentication and Security <security>`_ for details). Install via MacPorts:

.. code-block:: bash

    sudo port install docker colima gh

Or via Homebrew:

.. code-block:: bash

    brew install docker colima gh

**2. Start Colima**

Start the VM with one fewer CPU than your total core count:

.. code-block:: bash

    colima start --cpu $(( $(sysctl -n hw.ncpu) - 1 )) --memory 8

Colima runs a minimal Linux VM that starts in seconds and uses minimal
resources when idle. You only need to run this once after each reboot.

**3. Clone and install VVM**

.. code-block:: bash

    git clone https://github.com/VirtualPlanetaryLaboratory/vvm.git
    cd vvm
    chmod +x vvm
    sudo ln -sf "$(pwd)/vvm" /opt/local/bin/vvm

If using Homebrew, link to ``/usr/local/bin/vvm`` instead.

**4. Authenticate with GitHub and launch**

.. code-block:: bash

    gh auth login
    vvm

Choose **GitHub.com**, **HTTPS**, and **Login with a web browser** when
prompted. ``VVM`` reads the token from ``gh``'s credential store at
startup and passes it to the container via an ephemeral file that is
never stored in environment variables or shell history. See
`Authentication and Security <security>`_ for the full explanation.

Linux
-----

On Linux, Docker Engine provides the daemon natively. No VM is needed.

**1. Install Docker Engine and GitHub CLI**

Follow the official Docker instructions for your distribution at
`docs.docker.com/engine/install <https://docs.docker.com/engine/install/>`_.

On Ubuntu or Debian:

.. code-block:: bash

    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER

Log out and back in for the group change to take effect.

Install the GitHub CLI following `cli.github.com/manual/installation
<https://cli.github.com/manual/installation>`_.

**2. Clone and install VVM**

.. code-block:: bash

    git clone https://github.com/VirtualPlanetaryLaboratory/vvm.git
    cd vvm
    chmod +x vvm
    sudo ln -sf "$(pwd)/vvm" /usr/local/bin/vvm

**3. Authenticate with GitHub and launch**

.. code-block:: bash

    gh auth login
    vvm

Verifying the Installation
--------------------------

After ``VVM`` finishes its startup sequence, verify that the environment
is working:

.. code-block:: bash

    vplanet -v
    python -c "import vplanet; print(vplanet.__file__)"
    pytest /workspace/vspace/tests/ -x

The first command confirms the native C binary is on PATH. The second
confirms the Python package is importable. The third runs a test suite
to verify the full toolchain.
