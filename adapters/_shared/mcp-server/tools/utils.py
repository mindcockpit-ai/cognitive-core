"""
Shared utilities for cognitive-core MCP server tools.
"""
import os
import subprocess


def load_config(project_dir: str) -> dict:
    """
    Load CC_ variables from cognitive-core.conf.

    Searches for config in the project directory, then falls back
    to the .cognitive-core subdirectory.

    Args:
        project_dir: Project root directory.

    Returns:
        dict of CC_* environment variables.
    """
    conf_paths = [
        os.path.join(project_dir, "cognitive-core.conf"),
        os.path.join(project_dir, ".cognitive-core", "cognitive-core.conf"),
    ]
    for conf_path in conf_paths:
        if os.path.isfile(conf_path):
            try:
                cmd = f'set -a; source "{conf_path}" 2>/dev/null; env | grep "^CC_"'
                result = subprocess.run(
                    ["bash", "-c", cmd],
                    capture_output=True, text=True, timeout=5,
                )
                config: dict[str, str] = {}
                for line in result.stdout.strip().split("\n"):
                    if "=" in line:
                        key, _, value = line.partition("=")
                        config[key] = value
                return config
            except (subprocess.TimeoutExpired, FileNotFoundError):
                continue
    return {}


def list_dir_contents(install_dir: str, subdir: str) -> list[str]:
    """
    List files in a .cognitive-core subdirectory.

    Args:
        install_dir: cognitive-core install directory.
        subdir: Subdirectory name (e.g., "agents", "hooks", "skills").

    Returns:
        Sorted list of filenames.
    """
    dir_path = os.path.join(install_dir, subdir)
    if not os.path.isdir(dir_path):
        return []
    return sorted(os.listdir(dir_path))
