# cognitive-core MCP Server — Tool Boundaries

Platform-independent MCP server exposing cognitive-core capabilities over stdio
transport. Used by Claude Code (via `.mcp.json`), IntelliJ plugins (DevoxxGenie,
Continue.dev, Cline), and any MCP-compatible client.

## Transport

- **Protocol**: JSON-RPC 2.0 over stdio (line-delimited)
- **MCP version**: 2024-11-05
- **Dependencies**: Python 3.10+ stdlib only (no external packages)

## Tools

### cc_security_validate

Validates bash commands against cognitive-core safety rules before execution.

| Field | Value |
|-------|-------|
| **Purpose** | Pre-execution safety check for shell commands |
| **Boundary** | Read-only analysis — never executes the command |
| **Input** | `command` (string, required): bash command to validate |
| **Output** | `decision` (allow/deny), `reason` (explanation) |
| **Security** | Uses same patterns as `validate-bash.sh` hook |

```json
{
  "name": "cc_security_validate",
  "inputSchema": {
    "type": "object",
    "properties": {
      "command": { "type": "string", "description": "The bash command to validate" }
    },
    "required": ["command"]
  }
}
```

### cc_lint_check

Runs the project's configured lint or test command.

| Field | Value |
|-------|-------|
| **Purpose** | Execute lint/test in the project context |
| **Boundary** | Executes configured command only (CC_LINT_COMMAND or CC_TEST_COMMAND) |
| **Input** | `mode` (lint/test, default: lint), `path` (file/dir, default: ".") |
| **Output** | Command output, exit code, stdout, stderr |
| **Security** | Only runs pre-configured commands from cognitive-core.conf |

```json
{
  "name": "cc_lint_check",
  "inputSchema": {
    "type": "object",
    "properties": {
      "mode": { "type": "string", "enum": ["lint", "test"], "default": "lint" },
      "path": { "type": "string", "default": "." }
    }
  }
}
```

### cc_project_info

Returns project configuration and installed component inventory.

| Field | Value |
|-------|-------|
| **Purpose** | Project metadata and cognitive-core component inventory |
| **Boundary** | Read-only — reads cognitive-core.conf and directory listings |
| **Input** | None (empty object) |
| **Output** | Project name, language, architecture, agents, skills, hooks |
| **Security** | No sensitive data exposed (config values only) |

```json
{
  "name": "cc_project_info",
  "inputSchema": {
    "type": "object",
    "properties": {}
  }
}
```

### cc_hook_run

Executes a named cognitive-core hook with provided input.

| Field | Value |
|-------|-------|
| **Purpose** | Run hooks programmatically (same as hook dispatch in settings.json) |
| **Boundary** | Executes only hooks in the install directory — path traversal blocked |
| **Input** | `hook_name` (string, required), `input_json` (string, default: "{}") |
| **Output** | Hook stdout output |
| **Security** | Hook name sanitized (no `/` or `..`), 30s timeout |

```json
{
  "name": "cc_hook_run",
  "inputSchema": {
    "type": "object",
    "properties": {
      "hook_name": { "type": "string", "description": "Hook name (e.g., validate-bash)" },
      "input_json": { "type": "string", "default": "{}" }
    },
    "required": ["hook_name"]
  }
}
```

### cc_agent_context

Retrieves agent prompt content for delegation guidance.

| Field | Value |
|-------|-------|
| **Purpose** | Read agent definitions for routing and delegation decisions |
| **Boundary** | Read-only — returns agent .md file content |
| **Input** | `agent_name` (string, required) |
| **Output** | Full agent prompt content |
| **Security** | Agent name sanitized (no `/` or `..`), reads only from agents/ |

```json
{
  "name": "cc_agent_context",
  "inputSchema": {
    "type": "object",
    "properties": {
      "agent_name": { "type": "string", "description": "Agent name (e.g., project-coordinator)" }
    },
    "required": ["agent_name"]
  }
}
```

## Client Configuration

### Claude Code (.mcp.json)

```json
{
  "mcpServers": {
    "cognitive-core": {
      "command": "python3",
      "args": [".cognitive-core/mcp-server/server.py"],
      "env": {
        "CC_PROJECT_DIR": "${CLAUDE_PROJECT_DIR}",
        "CC_INSTALL_DIR": "${CLAUDE_PROJECT_DIR}/.cognitive-core"
      }
    }
  }
}
```

### IntelliJ (manual registration)

Register in your MCP-compatible plugin settings:
- **Command**: `python3 <project>/.cognitive-core/mcp-server/server.py`
- **Transport**: stdio
- **Environment**: `CC_PROJECT_DIR=<project-root>`
