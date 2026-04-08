"""
Shared utilities for cognitive-core MCP server tools.
"""
import os
import sys
from pathlib import Path

# Import load_config from the canonical shared module (#139 P3)
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))
from generate_utils import load_config as _load_config


def load_config(project_dir: str) -> dict:
    """Load CC_ variables from cognitive-core.conf.

    Delegates to generate_utils.load_config() — single source of truth.

    Args:
        project_dir: Project root directory.

    Returns:
        dict of CC_* environment variables.
    """
    return _load_config(project_dir=project_dir)


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
