Authentication and Security
===========================

``VVM`` needs to clone private GitHub repositories into the container.
This page explains how authentication works, why we chose this approach,
and what to do if something goes wrong.

How It Works
------------

When you run ``vvm`` on the host, four things happen:

1. The ``vvm`` script calls ``gh auth token`` to read your GitHub
   credential from the ``gh`` CLI's secure storage (your OS keychain).
2. The token is written to a temporary file in your home directory with
   permissions set to owner-only (mode 600).
3. Docker mounts that file read-only inside the container at
   ``/run/secrets/gh_token``.
4. The container's entrypoint reads the file and configures ``git`` to
   use HTTPS with the token for all GitHub URLs.

When the container exits, the ``vvm`` script deletes the temporary file.
If the script is interrupted (Ctrl+C, crash), a shell trap still runs
the cleanup. The token is never stored in an environment variable, never
appears in your shell history, and never shows up in ``docker inspect``.

Why Not SSH Keys?
-----------------

SSH is the standard way to authenticate with GitHub from a terminal.
We tried three variations before settling on the current approach:

**SSH agent forwarding** does not work on macOS with Colima. The SSH
agent socket lives on the macOS host, but Docker runs inside Colima's
lightweight Linux VM. The socket path cannot cross the VM boundary, so
the container cannot reach the agent.

**Mounting the SSH directory** (``~/.ssh``) read-only into the container
fails if the key has a passphrase. Without an agent to provide the
decrypted key, ``git`` prompts for the passphrase inside a non-interactive
environment and the clone fails.

**Generating a dedicated SSH key without a passphrase** would work, but
creates a long-lived credential on disk that is harder to audit and
rotate than a token managed by ``gh``.

Why Not Environment Variables?
------------------------------

A common pattern in Docker workflows is to pass credentials as
environment variables (``-e GITHUB_TOKEN=...``). We avoid this for
three reasons:

1. **Open-source visibility.** This repository is public. If the source
   code tells users to set ``GITHUB_TOKEN``, an attacker who reads the
   code knows exactly which environment variable to look for on any
   machine running ``VVM``. Ephemeral files at a randomized path reveal
   nothing useful.

2. **Container inspection.** Running ``docker inspect vvm`` prints every
   environment variable in plain text. A mounted file at
   ``/run/secrets/gh_token`` does not appear in ``docker inspect``.

3. **Shell history.** Typing ``export GITHUB_TOKEN=ghp_...`` saves the
   token in ``~/.zsh_history`` or ``~/.bash_history``. Using
   ``gh auth token`` reads from the OS keychain without user interaction.

Why the GitHub CLI?
-------------------

The `GitHub CLI <https://cli.github.com/>`_ (``gh``) stores credentials
in your operating system's keychain (Keychain Access on macOS,
``gnome-keyring`` or ``pass`` on Linux). This means:

- You authenticate once with ``gh auth login`` and never handle a token
  directly.
- The credential is encrypted at rest by the OS, not stored in a plain
  text file.
- Token rotation is as simple as ``gh auth refresh``.
- Fine-grained personal access tokens can be scoped to specific
  repositories with read-only permissions, limiting the impact of any
  leak.

Setup
-----

If you have not authenticated yet:

.. code-block:: bash

    gh auth login

Choose **GitHub.com**, **HTTPS** protocol, and **Login with a web browser**
when prompted. After authenticating, verify with:

.. code-block:: bash

    gh auth status

You should see your GitHub username and the active token source. From
this point, ``vvm`` reads the token automatically.

Troubleshooting
---------------

**"GitHub CLI not authenticated" warning on startup:**

Run ``gh auth login`` on the host (not inside the container). ``VVM``
reads the token before starting Docker.

**"No GitHub credentials found" inside the container:**

This means the token file was not mounted. On macOS with Colima, ensure
Colima is sharing your home directory (this is the default). Verify with
``colima list`` — the mount column should show ``~``.

**Token expired or revoked:**

Run ``gh auth refresh`` on the host, then restart the container.

**Want to use a different GitHub account:**

Run ``gh auth login`` again and select the new account. The next
``vvm`` invocation picks up the new credentials automatically.
