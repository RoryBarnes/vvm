"""Validate repos.conf format and content without Docker."""

import pathlib
import re

import pytest

REPO_ROOT = pathlib.Path(__file__).resolve().parent.parent
REPOS_CONF = REPO_ROOT / "repos.conf"

VALID_INSTALL_METHODS = {
    "c_and_pip",
    "pip_no_deps",
    "pip_editable",
    "scripts_only",
    "reference",
}

GIT_URL_PATTERN = re.compile(r"^git@github\.com:.+/.+\.git$")


def flistParseReposConf():
    """Parse repos.conf into a list of (name, url, branch, method) tuples."""
    listEntries = []
    for sLine in REPOS_CONF.read_text().splitlines():
        sStripped = sLine.strip()
        if not sStripped or sStripped.startswith("#"):
            continue
        listEntries.append(tuple(sStripped.split("|")))
    return listEntries


@pytest.fixture
def listEntries():
    return flistParseReposConf()


def test_repos_conf_exists():
    assert REPOS_CONF.is_file(), "repos.conf not found at repository root"


def test_repos_conf_not_empty(listEntries):
    assert len(listEntries) > 0, "repos.conf has no entries"


def test_each_line_has_four_fields(listEntries):
    for tEntry in listEntries:
        assert len(tEntry) == 4, (
            f"Expected 4 pipe-delimited fields, got {len(tEntry)}: {tEntry}"
        )


def test_no_duplicate_repo_names(listEntries):
    listNames = [tEntry[0] for tEntry in listEntries]
    setNames = set(listNames)
    assert len(listNames) == len(setNames), (
        f"Duplicate repo names: {[s for s in listNames if listNames.count(s) > 1]}"
    )


def test_install_methods_are_valid(listEntries):
    for sName, _sUrl, _sBranch, sMethod in listEntries:
        assert sMethod in VALID_INSTALL_METHODS, (
            f"'{sName}' has invalid install method '{sMethod}'. "
            f"Valid: {VALID_INSTALL_METHODS}"
        )


def test_urls_are_valid_git_ssh(listEntries):
    for sName, sUrl, _sBranch, _sMethod in listEntries:
        assert GIT_URL_PATTERN.match(sUrl), (
            f"'{sName}' URL does not match git SSH format: {sUrl}"
        )


def test_branch_names_are_nonempty(listEntries):
    for sName, _sUrl, sBranch, _sMethod in listEntries:
        assert sBranch.strip(), f"'{sName}' has empty branch name"


def test_repo_names_have_no_spaces(listEntries):
    for sName, _sUrl, _sBranch, _sMethod in listEntries:
        assert " " not in sName, f"Repo name contains space: '{sName}'"


def test_comments_and_blanks_are_skipped():
    """Verify the parser ignores comments and blank lines."""
    listAllLines = REPOS_CONF.read_text().splitlines()
    iCommentCount = sum(
        1 for s in listAllLines if s.strip().startswith("#")
    )
    iBlankCount = sum(1 for s in listAllLines if not s.strip())
    listEntries = flistParseReposConf()
    iDataLines = len(listAllLines) - iCommentCount - iBlankCount
    assert len(listEntries) == iDataLines
