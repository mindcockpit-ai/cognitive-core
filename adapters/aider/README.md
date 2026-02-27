# Aider + Ollama Adapter for cognitive-core

Run cognitive-core methodology with [Aider](https://aider.chat) and local LLMs via [Ollama](https://ollama.com) — no API keys needed.

## Prerequisites

- Python 3.10+
- [Ollama](https://ollama.com) installed and running
- [Aider](https://aider.chat/docs/install.html) installed (`pip install aider-chat`)
- A capable coding model pulled in Ollama (e.g., `qwen2.5-coder:32b`)

## Quick Start

```bash
# 1. Pull a coding model
ollama pull qwen2.5-coder:32b

# 2. Configure your project
cat > cognitive-core.conf << 'EOF'
CC_PROJECT_NAME="my-project"
CC_ORG="my-org"
CC_PLATFORM="aider"
CC_LANGUAGE="python"
CC_LINT_COMMAND="ruff check $1"
CC_TEST_COMMAND="pytest"
CC_AGENTS="coordinator reviewer"
CC_SKILLS="code-review"
CC_HOOKS="setup-env validate-bash"
CC_AIDER_MODEL="qwen2.5-coder:32b"
EOF

# 3. Install
bash /path/to/cognitive-core/install.sh /path/to/my-project

# 4. Launch
./cc-aider-start.sh
```

## What Gets Installed

| File | Purpose |
|------|---------|
| `.aider.conf.yml` | Aider configuration (model, lint, read-only files) |
| `CONVENTIONS.md` | Project conventions + safety rules (always in context) |
| `.aiderignore` | Files Aider should never read |
| `cc-aider-start.sh` | Launcher script with env setup |
| `.cognitive-core/agents/` | Agent docs (read-only reference) |
| `.cognitive-core/skills/` | Skill docs (read-only reference) |
| `.cognitive-core/hooks/` | Hook files (for convention extraction) |

## How Safety Works

Claude Code uses PreToolUse hooks to programmatically block dangerous commands. Aider doesn't have this mechanism, so safety is implemented via **conventions**:

1. Safety rules from `validate-bash.sh` are extracted into `CONVENTIONS.md`
2. `CONVENTIONS.md` is always in Aider's read-only context
3. The LLM reads these rules on every interaction
4. `.aiderignore` prevents access to sensitive files

**Note**: Convention-based safety is advisory, not enforced. The LLM should follow the rules but cannot be programmatically blocked.

## Feature Comparison

| Feature | Claude Code | Aider |
|---------|------------|-------|
| Safety hooks | Programmatic deny/allow | Convention-based |
| Agent delegation | Native sub-agents | Read-only context |
| Skill invocation | `/slash-commands` | Not supported |
| Auto-lint | PostToolUse hook | `auto-lint: true` config |
| Session start | SessionStart hook | Launcher script |
| Settings | `.claude/settings.json` | `.aider.conf.yml` |
| Project instructions | `CLAUDE.md` | `CONVENTIONS.md` |
| Web search | WebSearch tool | Not supported |
| MCP servers | Native | Not supported |

## Limitations

1. **No programmatic safety** — Safety rules are advisory only
2. **No sub-agent delegation** — Agent docs are reference material only
3. **No slash commands** — Skills cannot be invoked interactively
4. **No web search** — Model relies on training data and context
5. **No MCP servers** — External tool servers not supported
6. **Model quality varies** — Local LLMs may not match Claude's capabilities

## Recommended Models

For a Mac with 48GB+ RAM:

| Model | Size | Strength |
|-------|------|----------|
| `qwen2.5-coder:32b` | ~20GB | Best coding model for the size |
| `codellama:34b` | ~19GB | Good for code completion |
| `deepseek-coder-v2:16b` | ~9GB | Lighter alternative |

## Customization

Edit `cognitive-core.conf` and re-run `install.sh --force` to regenerate:

```bash
CC_AIDER_MODEL="qwen2.5-coder:32b"    # Ollama model name
CC_AIDER_OLLAMA_BASE="http://localhost:11434"  # Ollama URL
CC_AIDER_EDIT_FORMAT="diff"             # whole|diff|udiff
```
