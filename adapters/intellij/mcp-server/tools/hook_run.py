"""
Hook runner for cognitive-core MCP server.

Executes cognitive-core hooks with provided input, sanitizing hook names
to prevent path traversal attacks.
"""
import os
import subprocess


def run_hook(
    install_dir: str,
    hook_name: str,
    input_json: str = "{}",
    project_dir: str = ".",
    timeout: int = 30,
) -> dict:
    """
    Execute a cognitive-core hook.

    Args:
        install_dir: cognitive-core install directory.
        hook_name: Name of the hook (e.g., "validate-bash").
        input_json: JSON string to pass as stdin.
        project_dir: Working directory for the hook.
        timeout: Max execution time in seconds.

    Returns:
        dict with output, exit_code, error.
    """
    # Sanitize hook name
    if "/" in hook_name or ".." in hook_name:
        return {
            "output": "",
            "exit_code": -1,
            "error": "Invalid hook name (path traversal detected)",
        }

    # Find hook file
    hook_path = os.path.join(install_dir, "hooks", f"{hook_name}.sh")
    if not os.path.isfile(hook_path):
        hook_path = os.path.join(install_dir, "hooks", hook_name)
        if not os.path.isfile(hook_path):
            return {
                "output": "",
                "exit_code": -1,
                "error": f"Hook not found: {hook_name}",
            }

    try:
        result = subprocess.run(
            ["bash", hook_path],
            input=input_json,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=project_dir,
        )
        return {
            "output": result.stdout.strip(),
            "exit_code": result.returncode,
            "error": result.stderr.strip() if result.returncode != 0 else "",
        }
    except subprocess.TimeoutExpired:
        return {
            "output": "",
            "exit_code": -1,
            "error": f"Hook timed out after {timeout}s",
        }
    except FileNotFoundError:
        return {
            "output": "",
            "exit_code": -1,
            "error": "bash not found",
        }
