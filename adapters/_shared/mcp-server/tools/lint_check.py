"""
Lint/test command runner for cognitive-core MCP server.

Executes the project's configured lint or test command and returns the output.
"""
import shlex
import subprocess


def run_lint(
    project_dir: str,
    lint_command: str,
    path: str = ".",
    timeout: int = 120,
) -> dict:
    """
    Run a lint command in the project directory.

    Args:
        project_dir: Project root directory.
        lint_command: The lint command template (may contain $1).
        path: File/directory to check (replaces $1).
        timeout: Max execution time in seconds.

    Returns:
        dict with command, exit_code, stdout, stderr.
    """
    cmd = lint_command.replace("$1", shlex.quote(path))

    try:
        result = subprocess.run(
            ["bash", "-c", cmd],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=project_dir,
        )
        return {
            "command": cmd,
            "exit_code": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except subprocess.TimeoutExpired:
        return {
            "command": cmd,
            "exit_code": -1,
            "stdout": "",
            "stderr": f"Command timed out after {timeout}s",
        }
    except FileNotFoundError:
        return {
            "command": cmd,
            "exit_code": -1,
            "stdout": "",
            "stderr": "bash not found",
        }


def run_test(
    project_dir: str,
    test_command: str,
    timeout: int = 300,
) -> dict:
    """
    Run the project's test command.

    Args:
        project_dir: Project root directory.
        test_command: The test command to execute.
        timeout: Max execution time in seconds.

    Returns:
        dict with command, exit_code, stdout, stderr.
    """
    try:
        result = subprocess.run(
            ["bash", "-c", test_command],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=project_dir,
        )
        return {
            "command": test_command,
            "exit_code": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except subprocess.TimeoutExpired:
        return {
            "command": test_command,
            "exit_code": -1,
            "stdout": "",
            "stderr": f"Command timed out after {timeout}s",
        }
