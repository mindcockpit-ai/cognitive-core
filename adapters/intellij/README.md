# IntelliJ + Local LLM Adapter for cognitive-core

Run cognitive-core methodology with [IntelliJ IDEA](https://www.jetbrains.com/idea/) and local LLMs — no cloud API keys needed. Three integration layers for progressive capability.

## Prerequisites

- IntelliJ IDEA (any edition)
- [Ollama](https://ollama.com) installed and running
- An LLM plugin: [DevoxxGenie](https://plugins.jetbrains.com/plugin/23436-devoxxgenie), [Continue.dev](https://continue.dev), or [Cline](https://cline.bot)
- A capable coding model pulled in Ollama (e.g., `qwen2.5-coder:32b`)
- Python 3.9+ (for MCP server — Layer 2)

## Quick Start

```bash
# 1. Pull a coding model
ollama pull qwen2.5-coder:32b

# 2. Configure your project
cat > cognitive-core.conf << 'EOF'
CC_PROJECT_NAME="my-project"
CC_ORG="my-org"
CC_PLATFORM="intellij"
CC_LANGUAGE="java"
CC_LINT_COMMAND="mvn checkstyle:check"
CC_TEST_COMMAND="mvn test"
CC_AGENTS="coordinator reviewer"
CC_SKILLS="code-review"
CC_HOOKS="setup-env validate-bash"
CC_INTELLIJ_MODEL="qwen2.5-coder:32b"
EOF

# 3. Install
bash /path/to/cognitive-core/install.sh /path/to/my-project

# 4. Configure your IDE plugin to use DEVOXXGENIE.md as context
```

## What Gets Installed

| File | Purpose |
|------|---------|
| `DEVOXXGENIE.md` | Project conventions + safety rules (IDE context file) |
| `.devoxxgenie.yaml` | Plugin config (model, lint, MCP server) |
| `.cognitive-core/agents/` | Agent docs (read-only reference) |
| `.cognitive-core/skills/` | Skill docs (read-only reference) |
| `.cognitive-core/hooks/` | Hook files (for convention extraction) |
| `.cognitive-core/mcp-server/` | MCP server (Layer 2 — programmatic tools) |
| `.cognitive-core/mcp-config.json` | MCP server connection config for IDEs |

## Three Integration Layers

### Layer 1: Convention File (Universal)

Works with **any LLM plugin** and **any local model**. Safety rules and project standards in `DEVOXXGENIE.md` are loaded as context on every chat interaction.

- **Setup**: Add `DEVOXXGENIE.md` as a context file in your plugin settings
- **Safety**: Convention-based (advisory — LLM reads and follows the rules)
- **Agents**: Read-only documentation in `.cognitive-core/agents/`

### Layer 2: MCP Server (DevoxxGenie, Continue.dev, Cline)

Adds **programmatic tools** via the Model Context Protocol. The MCP server exposes cognitive-core capabilities as callable tools.

**Available tools:**

| Tool | Description |
|------|-------------|
| `cc_lint_check` | Run project lint/test command |
| `cc_security_validate` | Validate bash command against safety rules |
| `cc_project_info` | Return project config, agents, skills |
| `cc_hook_run` | Execute a cognitive-core hook |
| `cc_agent_context` | Retrieve agent prompt for guidance |

**MCP setup for DevoxxGenie:**
1. Open DevoxxGenie settings
2. Navigate to MCP Servers
3. Add server with transport `stdio`, command `python3`, args `.cognitive-core/mcp-server/server.py`

**MCP setup for Continue.dev:**
Add to `.continue/config.json`:
```json
{
  "mcpServers": [{
    "name": "cognitive-core",
    "command": "python3",
    "args": [".cognitive-core/mcp-server/server.py"]
  }]
}
```

### Layer 3: ACP Agent (Future — JetBrains 2025.3+)

Native JetBrains Agent Communication Protocol support. Deferred until ACP reaches v1.0+ stability (estimated Q3 2026).

## How Safety Works

| Layer | Mechanism | Enforcement |
|-------|-----------|-------------|
| Layer 1 | `DEVOXXGENIE.md` rules | Advisory (LLM reads rules) |
| Layer 2 | `cc_security_validate` MCP tool | Programmatic (returns deny/allow) |
| Claude Code | `validate-bash.sh` hook | Native (blocks execution) |

Safety patterns ported from `validate-bash.sh`:
- `rm -rf /` and system-critical paths
- `git push --force` to main/master
- `git reset --hard`
- `DROP TABLE` / `TRUNCATE TABLE`
- Pipe-to-shell (`curl | sh`)
- Encoded command execution (`base64 -d | sh`)
- Data exfiltration patterns

## Feature Comparison

| Feature | Claude Code | Aider | IntelliJ |
|---------|------------|-------|----------|
| Safety hooks | Native deny/allow | Convention-based | Convention + MCP |
| Agent delegation | Native sub-agents | Read-only context | Read-only + MCP lookup |
| Skill invocation | `/slash-commands` | Not supported | Not supported |
| Auto-lint | PostToolUse hook | `auto-lint: true` | MCP `cc_lint_check` |
| MCP servers | Native | Not supported | Layer 2 (native) |
| Settings | `.claude/settings.json` | `.aider.conf.yml` | `.devoxxgenie.yaml` |
| Project instructions | `CLAUDE.md` | `CONVENTIONS.md` | `DEVOXXGENIE.md` |
| Web search | WebSearch tool | Not supported | Not supported |

## Recommended Models

For a Mac with 48GB+ RAM:

| Model | Size | Strength |
|-------|------|----------|
| `qwen2.5-coder:32b` | ~20GB | Best coding model for the size |
| `deepseek-coder-v2:16b` | ~9GB | Good balance of quality and speed |
| `codellama:34b` | ~19GB | Good for code completion |
| `qwen2.5-coder:7b` | ~4.5GB | Lighter alternative for 16GB machines |

See DevoxxGenie's model compatibility list for more options.

## Limitations

1. **Layer 1 safety is advisory** — Convention rules depend on LLM compliance
2. **No sub-agent delegation** — Agent docs are reference only
3. **No slash commands** — Skills cannot be invoked interactively
4. **No web search** — Model relies on training data and context
5. **MCP requires plugin support** — Not all plugins implement MCP client
6. **Model quality varies** — Local LLMs may not match cloud model capabilities

## Customization

Edit `cognitive-core.conf` and re-run `install.sh --force` to regenerate:

```bash
CC_INTELLIJ_MODEL="qwen2.5-coder:32b"           # Ollama model name
CC_INTELLIJ_OLLAMA_BASE="http://localhost:11434"  # Ollama URL
```
