FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# System packages for vplanet C compilation and Python ecosystem
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    g++ \
    make \
    git \
    openssh-client \
    curl \
    ca-certificates \
    libhdf5-dev \
    liblapack-dev \
    libblas-dev \
    libffi-dev \
    pkg-config \
    software-properties-common \
    valgrind \
    lcov \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3.11-distutils \
    && rm -rf /var/lib/apt/lists/*

# Make python3.11 the default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
    && curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# All Python dependencies across the 9 repositories in a single cached layer.
# Using --no-deps on editable installs means these must cover every runtime need.
RUN pip install --no-cache-dir \
    "numpy>=1.24,<2.0" \
    "scipy>=1.10" \
    "matplotlib>=3.7" \
    "astropy>=5.0,<7.0" \
    "h5py>=3.8" \
    "pandas>=1.5" \
    "seaborn>=0.12" \
    "tqdm>=4.60" \
    "setuptools>=65" \
    "setuptools_scm>=8.0" \
    "wheel" \
    "pytest>=7.0" \
    "pytest-cov" \
    "pytest-dependency" \
    "pytest-env" \
    "pytest-timeout" \
    "coverage" \
    "george>=0.4" \
    "emcee>=3.0" \
    "dynesty>=2.0" \
    "corner>=2.2" \
    "scikit-learn>=1.2" \
    "scikit-optimize>=0.9" \
    "pybind11>=2.10" \
    "multiprocess>=0.70" \
    "SALib>=1.4" \
    "argparse"

RUN mkdir -p /workspace

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY repos.conf /etc/vvm/repos.conf
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN git config --system advice.detachedHead false

ENV WORKSPACE=/workspace
ENV VPLANET_BINARY=/workspace/vplanet-private/bin/vplanet
ENV PATH="/workspace/vplanet-private/bin:/workspace/MaxLEV:${PATH}"
ENV PYTHONPATH="/workspace/MaxLEV:${PYTHONPATH}"

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
