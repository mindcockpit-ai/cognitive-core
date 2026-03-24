# VS Code Adapter

Translates cognitive-core components into VS Code-compatible configuration
for GitHub Copilot, Continue.dev, and Cline.

## Integration Layers

| Layer | Mechanism | Extensions |
|-------|-----------|------------|
| 1 — Convention | `.github/copilot-instructions.md` | All LLM extensions |
| 2 — MCP Server | `.cognitive-core/mcp-server/` | Copilot 1.99+, Continue.dev, Cline |
| 3 — Language Server | Future | VS Code native |

## Generated Files

| File | Purpose |
|------|---------|
| `.github/copilot-instructions.md` | Project conventions, safety rules, agent context |
| `.vscode/mcp.json` | MCP server registration for VS Code 1.99+ |
| `.cognitive-core/mcp-server/` | MCP server providing lint, security, project info tools |
| `.cognitive-core/agents/` | Agent documentation (read-only context) |
| `.cognitive-core/hooks/` | Hook source files (for convention extraction) |
| `.cognitive-core/skills/` | Skill documentation (read-only context) |

## Installation

```bash
# Set CC_PLATFORM=vscode in cognitive-core.conf, then:
./install.sh /path/to/your-project
```

## MCP Server

The MCP server provides programmatic access to cognitive-core capabilities:

- **cc_lint_check** — Run project lint/test commands
- **cc_security_validate** — Validate bash commands against safety rules
- **cc_project_info** — Return project configuration and metadata
- **cc_hook_run** — Execute a cognitive-core hook
- **cc_agent_context** — Retrieve agent prompt for delegation guidance

### Configuration

VS Code 1.99+ reads `.vscode/mcp.json` automatically. For other extensions,
configure MCP with:

- Transport: `stdio`
- Command: `python3 .cognitive-core/mcp-server/server.py`

## Generator

The `generate.py` script can regenerate configuration files:

```bash
# Regenerate all files
python3 .cognitive-core/generate.py --mode all \
    --project-dir . --install-dir .cognitive-core \
    --config-file cognitive-core.conf

# Regenerate only MCP settings
python3 .cognitive-core/generate.py --mode settings ...

# Regenerate only instructions
python3 .cognitive-core/generate.py --mode instructions ...
```

## Safety Approach

Two-layer safety model:

1. **Convention** (Layer 1): Safety rules from `validate-bash.sh` are extracted
   into `.github/copilot-instructions.md`. GitHub Copilot loads this file
   automatically on every interaction.

2. **MCP** (Layer 2): The `cc_security_validate` MCP tool provides programmatic
   command validation before execution. Extensions supporting MCP can call this
   tool to validate commands.
