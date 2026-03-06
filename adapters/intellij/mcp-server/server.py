#!/usr/bin/env python3
"""
cognitive-core MCP Server for IntelliJ IDE plugins.

Exposes cognitive-core capabilities as MCP tools over stdio transport.
Works with DevoxxGenie, Continue.dev, Cline, and any MCP-compatible client.

Usage:
  python3 server.py

Environment:
  CC_PROJECT_DIR  — Project root directory (auto-detected if not set)
  CC_INSTALL_DIR  — cognitive-core install dir (default: <project>/.cognitive-core)
"""
import json
import os
import shlex
import subprocess
import sys
from pathlib import Path

# Resolve project paths
_PROJECT_DIR = os.environ.get("CC_PROJECT_DIR", os.getcwd())
_INSTALL_DIR = os.environ.get(
    "CC_INSTALL_DIR",
    os.path.join(_PROJECT_DIR, ".cognitive-core"),
)

# Import tool modules from tools/ directory
_TOOLS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools")
sys.path.insert(0, _TOOLS_DIR)

# MCP protocol constants
JSONRPC_VERSION = "2.0"
MCP_PROTOCOL_VERSION = "2024-11-05"

# Server metadata
SERVER_INFO = {
    "name": "cognitive-core",
    "version": "1.0.0",
}

# Tool registry
TOOLS = [
    {
        "name": "cc_lint_check",
        "description": "Run the project's lint or test command as configured in cognitive-core.conf.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "mode": {
                    "type": "string",
                    "enum": ["lint", "test"],
                    "description": "Run 'lint' or 'test' command",
                    "default": "lint",
                },
                "path": {
                    "type": "string",
                    "description": "Optional file or directory to check (passed as $1)",
                    "default": ".",
                },
            },
        },
    },
    {
        "name": "cc_security_validate",
        "description": "Validate a bash command against cognitive-core safety rules. Returns allow/deny with reason.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "command": {
                    "type": "string",
                    "description": "The bash command to validate",
                },
            },
            "required": ["command"],
        },
    },
    {
        "name": "cc_project_info",
        "description": "Return project configuration, installed agents, skills, and hooks from cognitive-core.",
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "cc_hook_run",
        "description": "Execute a named cognitive-core hook with provided input.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "hook_name": {
                    "type": "string",
                    "description": "Name of the hook to run (e.g., 'validate-bash')",
                },
                "input_json": {
                    "type": "string",
                    "description": "JSON string to pass as stdin to the hook",
                    "default": "{}",
                },
            },
            "required": ["hook_name"],
        },
    },
    {
        "name": "cc_agent_context",
        "description": "Retrieve the content of an agent's prompt file for delegation guidance.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "agent_name": {
                    "type": "string",
                    "description": "Agent name (e.g., 'project-coordinator', 'code-standards-reviewer')",
                },
            },
            "required": ["agent_name"],
        },
    },
]


def _load_config() -> dict:
    """Load CC_ variables from cognitive-core.conf."""
    try:
        from tools.utils import load_config
        return load_config(_PROJECT_DIR)
    except ImportError:
        pass
    # Inline fallback if utils not importable
    conf_path = os.path.join(_PROJECT_DIR, "cognitive-core.conf")
    if not os.path.isfile(conf_path):
        return {}
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
        return {}


def _list_dir_contents(subdir: str) -> list:
    """List files in a .cognitive-core subdirectory."""
    try:
        from tools.utils import list_dir_contents
        return list_dir_contents(_INSTALL_DIR, subdir)
    except ImportError:
        pass
    dir_path = os.path.join(_INSTALL_DIR, subdir)
    if not os.path.isdir(dir_path):
        return []
    return sorted(os.listdir(dir_path))


# ---- Tool implementations ----

def handle_cc_lint_check(arguments: dict) -> dict:
    """Run lint or test command."""
    config = _load_config()
    mode = arguments.get("mode", "lint")
    path = arguments.get("path", ".")

    if mode == "test":
        cmd = config.get("CC_TEST_COMMAND", "echo no-tests")
    else:
        cmd = config.get("CC_LINT_COMMAND", "echo no-lint")

    # Substitute $1 with path
    cmd = cmd.replace("$1", shlex.quote(path))

    try:
        result = subprocess.run(
            ["bash", "-c", cmd],
            capture_output=True, text=True, timeout=120,
            cwd=_PROJECT_DIR,
        )
        return {
            "content": [
                {
                    "type": "text",
                    "text": (
                        f"Command: {cmd}\n"
                        f"Exit code: {result.returncode}\n"
                        f"--- stdout ---\n{result.stdout}\n"
                        f"--- stderr ---\n{result.stderr}"
                    ),
                }
            ],
        }
    except subprocess.TimeoutExpired:
        return {
            "content": [{"type": "text", "text": f"Command timed out after 120s: {cmd}"}],
            "isError": True,
        }


def handle_cc_security_validate(arguments: dict) -> dict:
    """Validate a bash command against safety rules."""
    command = arguments.get("command", "")
    if not command:
        return {
            "content": [{"type": "text", "text": "Error: no command provided"}],
            "isError": True,
        }

    # Import the security validation module
    try:
        import security_validate
        result = security_validate.validate_command(command)
        return {
            "content": [{"type": "text", "text": json.dumps(result, indent=2)}],
        }
    except ImportError:
        # Fallback: inline validation
        result = _inline_security_validate(command)
        return {
            "content": [{"type": "text", "text": json.dumps(result, indent=2)}],
        }


def _inline_security_validate(command: str) -> dict:
    """Inline security validation fallback."""
    import re
    cmd_lower = command.lower()
    # Import from tools module if available, else use inline patterns
    try:
        import security_validate
        return security_validate.validate_command(command)
    except ImportError:
        pass

    # Minimal built-in patterns
    patterns = [
        (r'rm\s+(-[a-z]*f[a-z]*\s+)?(/|/etc|/usr|/var|/home|/System|/Library)(\s|$)',
         "rm targeting system-critical path"),
        (r'git\s+push\s+.*--force.*\s+(master|main)(\s|$)',
         "force push to main/master"),
        (r'git\s+reset\s+--hard', "git reset --hard (destructive)"),
        (r'(drop|truncate)\s+table', "DROP/TRUNCATE TABLE"),
        (r'rm\s+(-[a-z]*\s+)?\.git(\s|$|/)', "removing .git directory"),
        (r'chmod\s+777', "chmod 777 (insecure permissions)"),
        (r'curl\s+.*\|.*(ba)?sh', "pipe-to-shell (curl | sh)"),
        (r'wget\s+.*\|.*(ba)?sh', "pipe-to-shell (wget | sh)"),
        (r'base64.*-d.*\|.*(ba)?sh', "encoded command execution"),
        (r'eval\s+.*\$\(', "eval with command substitution"),
    ]

    for pattern, reason in patterns:
        if re.search(pattern, cmd_lower):
            return {"decision": "deny", "reason": f"Blocked: {reason}"}

    return {"decision": "allow", "reason": "Command passes safety validation"}


def handle_cc_project_info(arguments: dict) -> dict:
    """Return project configuration and metadata."""
    config = _load_config()

    info = {
        "project": config.get("CC_PROJECT_NAME", "unknown"),
        "language": config.get("CC_LANGUAGE", "unknown"),
        "architecture": config.get("CC_ARCHITECTURE", "none"),
        "database": config.get("CC_DATABASE", "none"),
        "main_branch": config.get("CC_MAIN_BRANCH", "main"),
        "security_level": config.get("CC_SECURITY_LEVEL", "standard"),
        "agents": _list_dir_contents("agents"),
        "skills": _list_dir_contents("skills"),
        "hooks": _list_dir_contents("hooks"),
        "lint_command": config.get("CC_LINT_COMMAND", ""),
        "test_command": config.get("CC_TEST_COMMAND", ""),
    }

    return {
        "content": [{"type": "text", "text": json.dumps(info, indent=2)}],
    }


def handle_cc_hook_run(arguments: dict) -> dict:
    """Execute a cognitive-core hook."""
    hook_name = arguments.get("hook_name", "")
    input_json = arguments.get("input_json", "{}")

    if not hook_name:
        return {
            "content": [{"type": "text", "text": "Error: no hook_name provided"}],
            "isError": True,
        }

    # Sanitize hook name (prevent path traversal)
    if "/" in hook_name or ".." in hook_name:
        return {
            "content": [{"type": "text", "text": "Error: invalid hook name"}],
            "isError": True,
        }

    hook_path = os.path.join(_INSTALL_DIR, "hooks", f"{hook_name}.sh")
    if not os.path.isfile(hook_path):
        hook_path = os.path.join(_INSTALL_DIR, "hooks", hook_name)
        if not os.path.isfile(hook_path):
            return {
                "content": [{"type": "text", "text": f"Error: hook not found: {hook_name}"}],
                "isError": True,
            }

    try:
        result = subprocess.run(
            ["bash", hook_path],
            input=input_json,
            capture_output=True, text=True, timeout=30,
            cwd=_PROJECT_DIR,
        )
        output = result.stdout.strip() or "(no output)"
        return {
            "content": [{"type": "text", "text": output}],
        }
    except subprocess.TimeoutExpired:
        return {
            "content": [{"type": "text", "text": f"Hook timed out after 30s: {hook_name}"}],
            "isError": True,
        }


def handle_cc_agent_context(arguments: dict) -> dict:
    """Retrieve agent prompt content."""
    agent_name = arguments.get("agent_name", "")

    if not agent_name:
        return {
            "content": [{"type": "text", "text": "Error: no agent_name provided"}],
            "isError": True,
        }

    # Sanitize
    if "/" in agent_name or ".." in agent_name:
        return {
            "content": [{"type": "text", "text": "Error: invalid agent name"}],
            "isError": True,
        }

    # Try with and without .md extension
    candidates = [
        os.path.join(_INSTALL_DIR, "agents", f"{agent_name}.md"),
        os.path.join(_INSTALL_DIR, "agents", agent_name),
    ]

    for agent_path in candidates:
        if os.path.isfile(agent_path):
            try:
                with open(agent_path, encoding="utf-8") as f:
                    content = f.read()
                return {
                    "content": [{"type": "text", "text": content}],
                }
            except OSError as e:
                return {
                    "content": [{"type": "text", "text": f"Error reading agent: {e}"}],
                    "isError": True,
                }

    available = _list_dir_contents("agents")
    return {
        "content": [{
            "type": "text",
            "text": f"Agent not found: {agent_name}\nAvailable: {', '.join(available)}",
        }],
        "isError": True,
    }


# ---- Tool dispatch ----

TOOL_HANDLERS = {
    "cc_lint_check": handle_cc_lint_check,
    "cc_security_validate": handle_cc_security_validate,
    "cc_project_info": handle_cc_project_info,
    "cc_hook_run": handle_cc_hook_run,
    "cc_agent_context": handle_cc_agent_context,
}


# ---- MCP Protocol ----

def handle_request(request: dict) -> dict:
    """Handle a single JSON-RPC request."""
    method = request.get("method", "")
    req_id = request.get("id")
    params = request.get("params", {})

    if method == "initialize":
        return _success(req_id, {
            "protocolVersion": MCP_PROTOCOL_VERSION,
            "capabilities": {
                "tools": {},
            },
            "serverInfo": SERVER_INFO,
        })

    elif method == "notifications/initialized":
        # Client acknowledgement — no response needed
        return None

    elif method == "tools/list":
        return _success(req_id, {"tools": TOOLS})

    elif method == "tools/call":
        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})

        handler = TOOL_HANDLERS.get(tool_name)
        if not handler:
            return _error(req_id, -32601, f"Unknown tool: {tool_name}")

        try:
            result = handler(arguments)
            return _success(req_id, result)
        except Exception as e:
            return _error(req_id, -32603, f"Tool error: {e}")

    elif method == "ping":
        return _success(req_id, {})

    else:
        return _error(req_id, -32601, f"Method not found: {method}")


def _success(req_id, result: dict) -> dict:
    return {
        "jsonrpc": JSONRPC_VERSION,
        "id": req_id,
        "result": result,
    }


def _error(req_id, code: int, message: str) -> dict:
    return {
        "jsonrpc": JSONRPC_VERSION,
        "id": req_id,
        "error": {"code": code, "message": message},
    }


def main():
    """Main loop: read JSON-RPC messages from stdin, write responses to stdout."""
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError:
            response = _error(None, -32700, "Parse error")
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()
            continue

        response = handle_request(request)
        if response is not None:
            sys.stdout.write(json.dumps(response) + "\n")
            sys.stdout.flush()


if __name__ == "__main__":
    main()
