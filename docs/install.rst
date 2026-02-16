Installation Guide
==================

``VVM`` requires **Docker** and **git** on the host machine. macOS also
requires a lightweight VM (Colima) to run Linux containers. No GitHub
account or authentication is needed for the default installation.

.. note::

   A fresh ``VVM`` install takes approximately **30 minutes** on a typical
   workstation. This includes installing Docker, building the container
   image, cloning all repositories, and compiling the ``VPLanet`` C binary.
   Subsequent starts take under a minute.

Automated Install
-----------------

The ``install_vvm.sh`` script detects your operating system and package
manager, installs all dependencies, clones ``VVM``, creates a symlink
so that ``vvm`` is available from any terminal, and adds the ``VVM``
utilities directory to your shell's ``PATH``.

.. code-block:: bash

    git clone https://github.com/RoryBarnes/vvm.git
    cd vvm
    sh install_vvm.sh

To include `Claude Code <https://docs.anthropic.com/en/docs/claude-code>`_
in the Docker image, pass the ``--claude`` flag:

.. code-block:: bash

    sh install_vvm.sh --claude

The installer adds the ``vvm/bin`` directory to your shell configuration
(``~/.zshrc``, ``~/.bashrc``, ``~/.bash_profile``, ``~/.config/fish/config.fish``,
or ``~/.profile`` depending on your shell). This makes utilities like
``connect_vvm`` available from any terminal. Open a new terminal or source
your shell config for the change to take effect.

The script supports macOS (MacPorts or Homebrew), Ubuntu/Debian, and
Fedora/RHEL. If you prefer to install manually, follow the instructions
below for your platform.

macOS
-----

**1. Install Docker CLI, Colima, and git**

`Colima <https://github.com/abiosoft/colima>`_ provides a lightweight Docker
daemon on macOS. Install via MacPorts:

.. code-block:: bash

    sudo port install docker colima

Or via Homebrew:

.. code-block:: bash

    brew install docker colima

**2. Start Colima**

Start the VM and allocate CPU cores (total minus one is recommended):

.. code-block:: bash

    colima start --cpu $(( $(sysctl -n hw.ncpu) - 1 )) --memory 8

Colima runs a minimal Linux VM that starts in seconds and uses minimal
resources when idle. You only need to run this command once after each
reboot.

**3. Clone and install VVM**

.. code-block:: bash

    git clone https://github.com/RoryBarnes/vvm.git
    cd vvm
    chmod +x vvm
    sudo ln -sf "$(pwd)/vvm" /opt/local/bin/vvm

If using Homebrew, link to ``$(brew --prefix)/bin/vvm`` instead.

**4. Launch**

.. code-block:: bash

    vvm

Linux (Ubuntu/Debian)
---------------------

**1. Install Docker Engine**

Follow the official Docker instructions at
`docs.docker.com/engine/install <https://docs.docker.com/engine/install/>`_,
or run:

.. code-block:: bash

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker $USER

Log out and back in for the group change to take effect.

**2. Clone and install VVM**

.. code-block:: bash

    git clone https://github.com/RoryBarnes/vvm.git
    cd vvm
    chmod +x vvm
    sudo ln -sf "$(pwd)/vvm" /usr/local/bin/vvm

**3. Launch**

.. code-block:: bash

    vvm

Linux (Fedora/RHEL)
-------------------

**1. Install Docker Engine**

.. code-block:: bash

    sudo dnf install -y dnf-plugins-core
    sudo dnf config-manager --add-repo \
        https://download.docker.com/linux/fedora/docker-ce.repo
    sudo dnf install -y docker-ce docker-ce-cli containerd.io
    sudo systemctl enable --now docker
    sudo usermod -aG docker $USER

Log out and back in for the group change to take effect.

**2. Clone and install VVM**

.. code-block:: bash

    git clone https://github.com/RoryBarnes/vvm.git
    cd vvm
    chmod +x vvm
    sudo ln -sf "$(pwd)/vvm" /usr/local/bin/vvm

**3. Launch**

.. code-block:: bash

    vvm

Verifying the Installation
--------------------------

After ``VVM`` finishes its startup sequence, verify that the environment
is working:

.. code-block:: bash

    vplanet -v
    python -c "import vplanet; print(vplanet.__file__)"
    cd /workspace/vplanet && make test

The first command confirms the native C binary is on ``PATH``. The second
confirms the Python package is importable. The third runs the ``VPLanet``
test suite.

A verification script is also available inside the container:

.. code-block:: bash

    sh /workspace/verify_vvm.sh

Uninstalling
------------

To remove ``VVM`` and all of its Docker resources, run the uninstall script
from the ``VVM`` repository directory:

.. code-block:: bash

    sh uninstall_vvm.sh

The script removes:

- The ``vvm:latest`` Docker image
- The ``vvm-workspace`` Docker volume (after confirmation, since it
  contains cloned repositories and local commits)
- The ``vvm`` symlink from the system bin directory
- The ``VVM`` PATH entries from your shell configuration

The script does **not** remove Docker, Colima, the GitHub CLI, or the
``VVM`` repository directory itself. To remove the repository after
uninstalling, delete the directory manually.

.. _private-repo-access:

For vplanet-private Developers
------------------------------

If you are an authorized collaborator who needs access to the private
``vplanet-private`` repository, you must also install the
`GitHub CLI <https://cli.github.com/>`_ and authenticate before launching
``VVM``.

**1. Install the GitHub CLI**

macOS (MacPorts): ``sudo port install gh``

macOS (Homebrew): ``brew install gh``

Ubuntu/Debian: follow `cli.github.com/manual/installation
<https://cli.github.com/manual/installation>`_

Fedora/RHEL: ``sudo dnf install gh``

**2. Authenticate**

.. code-block:: bash

    gh auth login

Choose **GitHub.com**, **HTTPS**, and **Login with a web browser** when
prompted. ``VVM`` reads the token from ``gh``'s credential store at
startup and passes it to the container via an ephemeral file. See
:doc:`security` for the full explanation.

**3. Launch VVM**

.. code-block:: bash

    vvm

When credentials are present, ``VVM`` automatically clones
``vplanet-private`` and builds the C binary from it instead of the
public ``vplanet`` repository.

.. note::

   Direct push access to ``vplanet-private`` is being phased out in
   favor of the public ``vplanet`` repository. New collaborators should
   fork the public repository and submit pull requests through GitHub.
   See :ref:`git-workflow` in the Usage guide.
