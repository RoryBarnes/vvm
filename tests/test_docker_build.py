"""Docker smoke tests for VVM image (Tier 3).

These tests require Docker to be running. They are marked with the 'docker'
marker so they can be skipped in fast CI runs:

    pytest tests/test_docker_build.py -v -m docker
    pytest tests/ -v -m "not docker"       # skip Docker tests
"""

import pathlib
import subprocess

import pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
IMAGE_NAME = "vvm:test"


def fbDockerAvailable():
    """Return True if the Docker daemon is reachable."""
    try:
        subprocess.run(
            ["docker", "info"],
            capture_output=True,
            timeout=10,
        )
        return True
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return False


bDockerRunning = fbDockerAvailable()
docker = pytest.mark.docker
skipWithoutDocker = pytest.mark.skipif(
    not bDockerRunning, reason="Docker daemon not available"
)


def fnDockerRun(sCommand):
    """Run a command inside a fresh container and return the result."""
    return subprocess.run(
        [
            "docker", "run", "--rm",
            "--entrypoint", "",
            IMAGE_NAME,
            "bash", "-c", sCommand,
        ],
        capture_output=True,
        text=True,
        timeout=30,
    )


@docker
@skipWithoutDocker
class TestDockerBuild:
    """Test that the Docker image builds successfully."""

    @pytest.fixture(scope="class", autouse=True)
    def build_image(self):
        """Build the Docker image once for all tests in this class."""
        result = subprocess.run(
            ["docker", "build", "-t", IMAGE_NAME, str(REPO_ROOT)],
            capture_output=True,
            text=True,
            timeout=600,
        )
        listTail = result.stdout.splitlines()[-50:]
        sTail = "\n".join(listTail)
        assert result.returncode == 0, (
            f"Docker build failed:\n{result.stderr}\n"
            f"Build output (last 50 lines):\n{sTail}"
        )

    def test_container_runs(self):
        result = fnDockerRun("echo ok")
        assert result.returncode == 0
        assert "ok" in result.stdout

    def test_python_version(self):
        result = fnDockerRun("python --version")
        assert result.returncode == 0
        assert "3.11" in result.stdout

    def test_gcc_available(self):
        result = fnDockerRun("gcc --version")
        assert result.returncode == 0

    def test_make_available(self):
        result = fnDockerRun("make --version")
        assert result.returncode == 0

    def test_git_available(self):
        result = fnDockerRun("git --version")
        assert result.returncode == 0

    def test_valgrind_available(self):
        result = fnDockerRun("valgrind --version")
        assert result.returncode == 0

    def test_pip_packages_installed(self):
        """Verify key pip packages are importable."""
        listPackages = [
            "numpy", "scipy", "matplotlib", "astropy",
            "h5py", "pandas", "pytest", "emcee",
        ]
        sImports = "; ".join(
            f"import {s}" for s in listPackages
        )
        result = fnDockerRun(f"python -c '{sImports}'")
        assert result.returncode == 0, (
            f"Failed to import packages:\n{result.stderr}"
        )

    def test_workspace_directory_exists(self):
        result = fnDockerRun("test -d /workspace && echo ok")
        assert "ok" in result.stdout

    def test_entrypoint_is_executable(self):
        result = fnDockerRun(
            "test -x /usr/local/bin/entrypoint.sh && echo ok"
        )
        assert "ok" in result.stdout

    def test_repos_conf_is_present(self):
        result = fnDockerRun("test -f /etc/vvm/repos.conf && echo ok")
        assert "ok" in result.stdout
