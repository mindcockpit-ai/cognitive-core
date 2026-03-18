"""
Project information provider for cognitive-core MCP server.

Reads cognitive-core.conf and directory structure to build project metadata.
"""
from tools.utils import list_dir_contents, load_config


def get_project_info(project_dir: str, install_dir: str) -> dict:
    """
    Gather project configuration and installed components.

    Args:
        project_dir: Project root directory.
        install_dir: cognitive-core install directory.

    Returns:
        dict with project metadata, agents, skills, hooks.
    """
    config = load_config(project_dir)

    return {
        "project": config.get("CC_PROJECT_NAME", "unknown"),
        "description": config.get("CC_PROJECT_DESCRIPTION", ""),
        "organization": config.get("CC_ORG", ""),
        "language": config.get("CC_LANGUAGE", "unknown"),
        "architecture": config.get("CC_ARCHITECTURE", "none"),
        "database": config.get("CC_DATABASE", "none"),
        "main_branch": config.get("CC_MAIN_BRANCH", "main"),
        "security_level": config.get("CC_SECURITY_LEVEL", "standard"),
        "lint_command": config.get("CC_LINT_COMMAND", ""),
        "test_command": config.get("CC_TEST_COMMAND", ""),
        "agents": list_dir_contents(install_dir, "agents"),
        "skills": list_dir_contents(install_dir, "skills"),
        "hooks": list_dir_contents(install_dir, "hooks"),
    }
