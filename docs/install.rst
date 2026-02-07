Installation Guide
==================

``VVM`` requires Docker and a Docker runtime. The installation differs
between macOS and Linux because macOS needs a lightweight VM to run Linux
containers.

macOS
-----

**1. Install Docker CLI and Colima**

`Colima <https://github.com/abiosoft/colima>`_ provides a lightweight Docker daemon
on macOS. Install via MacPorts:

.. code-block:: bash

    sudo port install docker colima

Or via Homebrew:

.. code-block:: bash

    brew install docker colima

**2. Start Colima**

.. code-block:: bash

    colima start --cpu 9 --memory 8

Adjust ``--cpu`` to one less than your total core count (check with
``sysctl -n hw.ncpu``). Colima runs a minimal Linux VM that starts in
seconds and uses minimal resources when idle.

**3. Clone and install VVM**

.. code-block:: bash

    git clone https://github.com/VirtualPlanetaryLaboratory/vvm.git
    cd vvm
    chmod +x vvm
    sudo ln -sf "$(pwd)/vvm" /opt/local/bin/vvm

If using Homebrew, link to ``/usr/local/bin/vvm`` instead.

**4. Load your SSH key and launch**

.. code-block:: bash

    ssh-add ~/.ssh/id_ed25519
    vvm

The SSH key is needed for cloning private repositories. ``VVM`` forwards your
SSH agent into the container so you can also push commits from inside.

Linux
-----

On Linux, Docker Engine provides the daemon natively. No VM is needed.

**1. Install Docker Engine**

Follow the official instructions for your distribution at
`docs.docker.com/engine/install <https://docs.docker.com/engine/install/>`_.

On Ubuntu or Debian:

.. code-block:: bash

    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER

Log out and back in for the group change to take effect.

**2. Clone and install VVM**

.. code-block:: bash

    git clone https://github.com/VirtualPlanetaryLaboratory/vvm.git
    cd vvm
    chmod +x vvm
    sudo ln -sf "$(pwd)/vvm" /usr/local/bin/vvm

**3. Load your SSH key and launch**

.. code-block:: bash

    ssh-add ~/.ssh/id_ed25519
    vvm

Verifying the Installation
--------------------------

After ``vvm`` finishes its startup sequence, verify that the environment
is working:

.. code-block:: bash

    vplanet -v
    python -c "import vplanet; print(vplanet.__file__)"
    pytest /workspace/vspace/tests/ -x

The first command confirms the native C binary is on PATH. The second
confirms the Python package is importable. The third runs a test suite
to verify the full toolchain.
