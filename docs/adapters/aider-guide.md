# Aider + Ollama Adapter — Comprehensive Guide

## Architecture Overview

The Aider adapter translates cognitive-core's Claude Code-centric architecture into Aider-compatible configuration. The key challenge is that Aider lacks several Claude Code features (hooks, sub-agents, slash commands), so the adapter uses convention-based and configuration-based equivalents.

```
cognitive-core Framework
        │
        ├── adapters/claude/   (identity — direct mapping)
        │
        └── adapters/aider/    (translation layer)
                │
                ├── adapter.sh       Shell adapter interface
                ├── generate.py      Python conversion engine
                ├── tool-map.yaml    Capability mapping
                └── templates/       CONVENTIONS.md template
```

### Translation Strategy

| cognitive-core Concept | Claude Code | Aider Equivalent |
|------------------------|-------------|------------------|
| PreToolUse hooks | Bash script → deny/allow JSON | CONVENTIONS.md rules |
| PostToolUse hooks | Bash script after edit | `auto-lint: true` in config |
| SessionStart hooks | Bash script on session start | `cc-aider-start.sh` launcher |
| Notification hooks | Compact reminder | Not supported |
| Agent definitions | `.claude/agents/*.md` | Read-only context files |
| Skill definitions | `.claude/skills/*/SKILL.md` | Read-only context files |
| settings.json | Hooks + permissions + env | `.aider.conf.yml` |
| CLAUDE.md | Project instructions | `CONVENTIONS.md` |

## Installation

### Prerequisites

1. **Python 3.10+** — For the conversion engine
2. **Ollama** — Local LLM server

   ```bash
   # macOS
   brew install ollama
   ollama serve  # Start in background
   ```

3. **Aider** — AI coding assistant

   ```bash
   pip install aider-chat
   ```

4. **A coding model** — Pull via Ollama

   ```bash
   ollama pull qwen2.5-coder:32b
   ```

### Install Steps

```bash
# Create cognitive-core.conf with CC_PLATFORM=aider
cat > /path/to/project/cognitive-core.conf << 'EOF'
CC_PROJECT_NAME="my-project"
CC_PROJECT_DESCRIPTION="My awesome project"
CC_ORG="my-org"
CC_PLATFORM="aider"
CC_LANGUAGE="python"
CC_LINT_COMMAND="ruff check $1"
CC_TEST_COMMAND="pytest"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator reviewer architect tester researcher"
CC_SKILLS="code-review security-baseline"
CC_HOOKS="setup-env validate-bash validate-read validate-write"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES="api core db"
CC_SECURITY_LEVEL="standard"
CC_AIDER_MODEL="qwen2.5-coder:32b"
CC_AIDER_OLLAMA_BASE="http://localhost:11434"
CC_AIDER_EDIT_FORMAT="diff"
CC_ENABLE_CICD="false"
CC_MONITORING="false"
CC_ENABLE_CLEANUP_CRON="false"
EOF

# Run installer
bash /path/to/cognitive-core/install.sh /path/to/project

# Launch
cd /path/to/project
./cc-aider-start.sh
```

## Generated Files

### .aider.conf.yml

Aider reads this YAML file for configuration. The adapter generates it with:

- **Model selection**: Points to your Ollama model
- **Auto-lint**: Enabled by default, uses your `CC_LINT_COMMAND`
- **Read-only context**: `CONVENTIONS.md` and all agent `.md` files are always loaded

### CONVENTIONS.md

This is the Aider equivalent of `CLAUDE.md`. It is always loaded into Aider's context via the `read:` directive in `.aider.conf.yml`. It contains:

1. **Project identity** — Name, language, architecture
2. **Code standards** — Lint/test commands, best practices
3. **Git conventions** — Commit format, branch rules
4. **Safety rules** — Extracted from `validate-bash.sh`
5. **Architecture** — Pattern, source/test roots
6. **Key rules** — From `CC_COMPACT_RULES`
7. **Agent context** — Links to agent documentation files

### .aiderignore

Prevents Aider from reading sensitive files. Includes:
- `.env` and credential files
- Build artifacts (`node_modules/`, `__pycache__/`)
- IDE configuration
- Runtime logs

### cc-aider-start.sh

Launcher script that:
1. Sources `cognitive-core.conf` for environment variables
2. Sets `OLLAMA_API_BASE`
3. Exports any `CC_ENV_VARS`
4. Launches Aider

## Safety Implementation

### How validate-bash.sh Rules Become Conventions

The adapter's `generate.py` reads `validate-bash.sh` and extracts all `REASON="Blocked: ..."` strings. These become explicit safety rules in `CONVENTIONS.md`:

**Before (Claude Code hook)**:
```bash
if echo "$CMD_LOWER" | grep -qE 'rm -rf /'; then
    REASON="Blocked: rm targeting system-critical path"
fi
```

**After (Aider convention)**:
```markdown
## Safety Rules (CRITICAL)
- NEVER: rm targeting system-critical path
- NEVER: force push to main
```

### Limitations of Convention-Based Safety

| Aspect | Claude Code | Aider |
|--------|------------|-------|
| Enforcement | Programmatic (hook returns deny JSON) | Advisory (LLM reads instructions) |
| Bypass risk | None (command blocked before execution) | Model may ignore conventions |
| Audit trail | security.log with every deny | No audit trail |

**Recommendation**: For production/sensitive environments, use Claude Code with full hook-based safety. Aider with conventions is suitable for development and personal use.

## Ollama Setup

### Recommended Models by RAM

| RAM | Model | Context Window |
|-----|-------|----------------|
| 16GB | `deepseek-coder-v2:16b` | 128K |
| 32GB | `qwen2.5-coder:32b` | 32K |
| 48GB | `qwen2.5-coder:32b` + room for context | 32K |
| 64GB+ | `codestral:22b` or multiple models | Varies |

### Ollama Configuration

```bash
# Start Ollama (if not already running)
ollama serve

# Pull your chosen model
ollama pull qwen2.5-coder:32b

# Verify it works
ollama run qwen2.5-coder:32b "Write a hello world in Python"
```

### Remote Ollama

If Ollama runs on a different machine:

```bash
CC_AIDER_OLLAMA_BASE="http://192.168.1.100:11434"
```

## Troubleshooting

### "Model not found"

```bash
# Verify model is pulled
ollama list

# Pull if missing
ollama pull qwen2.5-coder:32b
```

### "Connection refused"

```bash
# Verify Ollama is running
curl http://localhost:11434/api/tags

# Start if needed
ollama serve
```

### Poor Code Quality

- Try a larger model if RAM allows
- Use `edit-format: whole` for simpler edits
- Add more context files to `read:` in `.aider.conf.yml`
- Add specific coding patterns to `CONVENTIONS.md`

### Regenerating After Config Changes

```bash
# Re-run install with --force
bash /path/to/cognitive-core/install.sh /path/to/project --force
```

Or regenerate specific files:

```bash
# Just CONVENTIONS.md
python3 .cognitive-core/hooks/generate.py --mode conventions \
    --project-dir . --install-dir .cognitive-core \
    --config-file cognitive-core.conf

# Just .aider.conf.yml
python3 .cognitive-core/hooks/generate.py --mode settings \
    --project-dir . --install-dir .cognitive-core \
    --config-file cognitive-core.conf
```
