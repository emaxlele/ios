#!/usr/bin/env python3
# Requires Python 3.9+
"""Update SPM dependencies in xcodegen project YAML files.

Fetches the latest stable releases (for ``exactVersion`` packages) or latest commit
SHAs (for ``revision``/``branch`` packages) from the GitHub API via the ``gh`` CLI,
updates the project files in place, and writes a Markdown summary for use as a PR body.

Usage:
    ./Scripts/update-dependencies.py
"""

import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import yaml
from packaging import version


SUMMARY_FILE = "spm-update-summary.md"


class GitHubClient:
    """Client for GitHub API calls via the ``gh`` CLI."""

    def get_latest_release(self, repo_url: str) -> Optional[str]:
        """Get the latest stable release tag for a GitHub repository.

        Stable means non-prerelease and without beta/alpha/rc/pre/dev/snapshot
        in the tag name. Falls back to the tags list if the releases endpoint
        returns nothing usable.

        Args:
            repo_url: Full GitHub HTTPS URL of the repository.

        Returns:
            The tag name of the latest stable release, or None if not found.
        """
        repo_path = repo_url.removeprefix("https://github.com/")

        for release in self._call_api(f"repos/{repo_path}/releases"):
            if not release.get("prerelease", False):
                tag_name = release.get("tag_name", "")
                if not _is_prerelease_tag(tag_name):
                    return tag_name

        for tag in self._call_api(f"repos/{repo_path}/tags"):
            tag_name = tag.get("name", "")
            if not _is_prerelease_tag(tag_name):
                return tag_name

        return None

    def get_latest_commit(self, repo_url: str, branch: str) -> Optional[str]:
        """Get the latest commit SHA on a specific branch.

        Args:
            repo_url: Full GitHub HTTPS URL of the repository.
            branch: Branch name to query.

        Returns:
            The full commit SHA, or None if the API call fails.
        """
        repo_path = repo_url.removeprefix("https://github.com/")
        data = self._call_api(f"repos/{repo_path}/commits/{branch}")
        sha = data.get("sha")
        return sha if isinstance(sha, str) else None

    def _call_api(self, endpoint: str) -> object:
        """Run ``gh api`` and return the parsed JSON response.

        Args:
            endpoint: GitHub API path (without a leading slash).

        Returns:
            Parsed JSON as a dict or list; an empty dict on any error.
        """
        try:
            result = subprocess.run(
                ["gh", "api", endpoint],
                capture_output=True,
                text=True,
                check=True,
            )
            return json.loads(result.stdout)
        except subprocess.CalledProcessError as e:
            print(f"  Error calling GitHub API ({endpoint}): {e.stderr.strip()}")
            return {}
        except json.JSONDecodeError as e:
            print(f"  Error parsing JSON from {endpoint}: {e}")
            return {}


@dataclass
class PackageUpdate:
    """A dependency that was updated in a project file.

    Attributes:
        package_name: The package's key in the YAML ``packages`` map.
        source_file: Path to the project file that was modified.
        old_value: The previous version tag or revision SHA.
        new_value: The updated version tag or revision SHA.
        update_kind: ``"version"`` for ``exactVersion`` updates, ``"revision"``
            for ``revision``/``branch`` updates.
    """

    package_name: str
    source_file: str
    old_value: str
    new_value: str
    update_kind: str


class ProjectFileUpdater:
    """Reads one xcodegen project YAML file and updates its dependencies.

    Attributes:
        path: Path to the project YAML file.
        client: GitHub API client for version and commit lookups.
    """

    def __init__(self, path: str, client: GitHubClient) -> None:
        """Initialize an updater for a specific project file.

        Args:
            path: Filesystem path to the xcodegen YAML file.
            client: Shared GitHub API client.
        """
        self.path = path
        self.client = client

    def process(self) -> list[PackageUpdate]:
        """Update all out-of-date packages in the project file.

        Reads the YAML, checks each package against the GitHub API, mutates
        package entries in place for any that have updates, then writes the
        file back if anything changed.

        Returns:
            A list of PackageUpdate records for every dependency that was bumped.
        """
        if not Path(self.path).is_file():
            print(f"Warning: {self.path} not found, skipping...")
            return []

        print(f"Processing {self.path}...")

        try:
            with open(self.path, "r") as f:
                data = yaml.safe_load(f)
        except yaml.YAMLError as e:
            print(f"  Error reading {self.path}: {e}")
            return []

        packages = data.get("packages") or {}
        if not packages:
            print(f"  No packages found in {self.path}")
            return []

        updates: list[PackageUpdate] = []
        for package_name, package_info in packages.items():
            update = self._process_package(package_name, package_info)
            if update is not None:
                updates.append(update)

        if updates:
            print(f"  Updates found. Writing changes to {self.path}...")
            try:
                with open(self.path, "w") as f:
                    yaml.safe_dump(data, f, default_flow_style=False, sort_keys=False)
                print("  File updated successfully.")
            except Exception as e:
                print(f"  Error writing {self.path}: {e}")
                return []
        else:
            print(f"  No updates needed for {self.path}.")

        return updates

    def _process_package(self, name: str, info: dict) -> Optional[PackageUpdate]:
        """Check one package entry and update it if a newer version is available.

        Args:
            name: The package key as it appears in the YAML.
            info: The package value dict (url, exactVersion, revision, branch);
                mutated in place if an update is applied.

        Returns:
            A PackageUpdate if the package was bumped, or None otherwise.
        """
        print(f"  Processing package: {name}")

        url = info.get("url", "")
        exact_version = info.get("exactVersion")
        revision = info.get("revision")
        branch = info.get("branch")

        if not url.startswith("https://github.com/"):
            print(f"    {name}: Not a GitHub URL, skipping...")
            return None

        if exact_version:
            return self._update_version(name, info, url, str(exact_version))

        if revision and branch:
            return self._update_revision(name, info, url, str(revision), str(branch))

        print(f"    {name}: No version or revision info found, skipping...")
        return None

    def _update_version(
        self,
        name: str,
        info: dict,
        url: str,
        current: str,
    ) -> Optional[PackageUpdate]:
        """Check for and apply a newer release version.

        Args:
            name: Package name (for logging).
            info: Package dict; ``exactVersion`` is mutated on update.
            url: GitHub repository URL.
            current: Current ``exactVersion`` string.

        Returns:
            A PackageUpdate if a newer release was found and applied, else None.
        """
        latest = self.client.get_latest_release(url)
        if latest and _is_older(current, latest):
            print(f"    Updating {name}: {current} → {latest}")
            info["exactVersion"] = latest
            return PackageUpdate(
                package_name=name,
                source_file=self.path,
                old_value=current,
                new_value=latest,
                update_kind="version",
            )
        print(f"    {name} is up to date ({current})")
        return None

    def _update_revision(
        self,
        name: str,
        info: dict,
        url: str,
        current: str,
        branch: str,
    ) -> Optional[PackageUpdate]:
        """Check for and apply a newer commit revision.

        Args:
            name: Package name (for logging).
            info: Package dict; ``revision`` is mutated on update.
            url: GitHub repository URL.
            current: Current revision SHA.
            branch: Branch to query for the latest commit.

        Returns:
            A PackageUpdate if a newer commit was found and applied, else None.
        """
        latest = self.client.get_latest_commit(url, branch)
        if latest and latest != current:
            print(f"    Updating {name} revision: {current[:8]}… → {latest[:8]}…")
            info["revision"] = latest
            return PackageUpdate(
                package_name=name,
                source_file=self.path,
                old_value=current,
                new_value=latest,
                update_kind="revision",
            )
        print(f"    {name} revision is up to date ({current[:8]}…)")
        return None


class DependencyUpdateRunner:
    """Orchestrates dependency updates across all xcodegen project files.

    Attributes:
        PROJECT_FILES: xcodegen YAML files to process (relative to repo root).
        client: Shared GitHub API client used by all file updaters.
    """

    PROJECT_FILES: list[str] = ["project-bwk.yml", "project-bwa.yml", "project-pm.yml"]

    def __init__(self) -> None:
        """Initialize the runner with a fresh GitHub client."""
        self.client = GitHubClient()

    def run(self) -> list[PackageUpdate]:
        """Process every configured project file and collect all updates.

        Returns:
            A flat list of every PackageUpdate applied across all project files.
        """
        print("Checking for dependency updates...")
        all_updates: list[PackageUpdate] = []

        for project_file in self.PROJECT_FILES:
            updater = ProjectFileUpdater(project_file, self.client)
            all_updates.extend(updater.process())

        print("All project files processed.")
        return all_updates

    def write_summary(self, updates: list[PackageUpdate], output_path: str) -> None:
        """Write a Markdown summary of all applied updates.

        The summary is suitable for use as a GitHub PR body.

        Args:
            updates: Updates that were applied this run.
            output_path: File path to write the Markdown to.
        """
        lines: list[str] = ["Updates the following SPM dependencies:\n"]

        if not updates:
            lines.append("No dependencies were updated.")
        else:
            lines.append("| Package | Type | Old | New |")
            lines.append("|---------|------|-----|-----|")
            for u in updates:
                if u.update_kind == "version":
                    old, new = u.old_value, u.new_value
                else:
                    old = u.old_value[:8] + "…"
                    new = u.new_value[:8] + "…"
                lines.append(f"| {u.package_name} | {u.update_kind} | `{old}` | `{new}` |")

        with open(output_path, "w") as f:
            f.write("\n".join(lines) + "\n")


def _is_prerelease_tag(tag: str) -> bool:
    """Return True if the tag name looks like a pre-release.

    Args:
        tag: The release or tag name to inspect.

    Returns:
        True if the tag contains beta/alpha/rc/pre/dev/snapshot (case-insensitive).
    """
    return bool(re.search(r"(beta|alpha|rc|pre|dev|snapshot)", tag, re.IGNORECASE))


def _is_older(current: str, latest: str) -> bool:
    """Return True if ``current`` is an older version than ``latest``.

    Strips leading ``v`` before comparing. Falls back to string inequality
    if either string is not a valid PEP 440 version.

    Args:
        current: The installed version string.
        latest: The candidate version string.

    Returns:
        True if ``current`` is strictly older than ``latest``; False otherwise.
    """
    c = current.lstrip("v")
    n = latest.lstrip("v")
    if c == n:
        return False
    try:
        return version.parse(c) < version.parse(n)
    except version.InvalidVersion:
        return c != n


def main() -> None:
    """Run all dependency updates and write a Markdown summary to ``SUMMARY_FILE``."""
    runner = DependencyUpdateRunner()
    updates = runner.run()
    runner.write_summary(updates, SUMMARY_FILE)
    print(f"Summary written to {SUMMARY_FILE}")


if __name__ == "__main__":
    main()
