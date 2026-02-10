VVM Documentation
=================

``VVM`` (Virtual VPLanet Machine) is an isolated Docker container for the complete
`VPLanet <https://github.com/VirtualPlanetaryLaboratory/vplanet>`_ development ecosystem.
It packages all 9 repositories into a single, reproducible environment where code changes
cannot affect the host filesystem. A single ``vvm`` command starts the container, pulls
the latest code from GitHub, compiles ``VPLanet``, installs all Python packages, and drops
into a ready-to-use shell.

``VVM`` is designed for safe, long-running AI-assisted coding sessions and multi-agent
workflows. All repositories persist in a Docker named volume that is fully isolated from
the host.

.. toctree::
   :maxdepth: 1

   install
   quickstart
   usage
   security
   GitHub <https://github.com/RoryBarnes/vvm>

Repositories
------------

``VVM`` manages the following repositories:

.. list-table::
   :header-rows: 1
   :widths: 20 60

   * - Repository
     - Description
   * - `vplanet-private <https://github.com/VirtualPlanetaryLaboratory/vplanet-private>`_
     - VPLanet C source and Python package (branch: v3.0)
   * - `vplot <https://github.com/VirtualPlanetaryLaboratory/vplot>`_
     - Plotting package for VPLanet output
   * - `vspace <https://github.com/VirtualPlanetaryLaboratory/vspace>`_
     - Parameter sweep generator
   * - `bigplanet <https://github.com/VirtualPlanetaryLaboratory/bigplanet>`_
     - HDF5 compression and analysis
   * - `multi-planet <https://github.com/VirtualPlanetaryLaboratory/multi-planet>`_
     - Multi-core simulation runner
   * - `alabi <https://github.com/RoryBarnes/alabi>`_
     - Machine learning posterior inference
   * - `vplanet_inference <https://github.com/jbirky/vplanet_inference>`_
     - Interface for Bayesian inference
   * - `MaxLEV <https://github.com/RoryBarnes/MaxLEV>`_
     - Maximum likelihood estimator
   * - `vplanet <https://github.com/VirtualPlanetaryLaboratory/vplanet>`_
     - Public VPLanet (reference copy)
