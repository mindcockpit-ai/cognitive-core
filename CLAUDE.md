# cognitive-core Development Guide

## Quick Reference

| Item | Value |
|------|-------|
| **Project** | cognitive-core |
| **Description** | AI-augmented development framework for coding assistants |
| **Organization** | mindcockpit-ai |
| **Language** | Bash (primary) + Python (adapters) |
| **Architecture** | Layered (core/, adapters/, language-packs/, database-packs/) |
| **Main Branch** | main |
| **Test Command** | `bash tests/run-all.sh` |
| **Lint Command** | `bash -n $1` (shell syntax check) |
| **Project Board** | [cognitive-core Development](https://github.com/orgs/mindcockpit-ai/projects/9) |

## Architecture

```
cognitive-core/
├── core/                    # Framework components
│   ├── hooks/               # Safety hooks (validate-bash, validate-read, etc.)
│   ├── agents/              # Agent definitions (.md with YAML frontmatter)
│   ├── skills/              # Skill definitions (SKILL.md + references/)
│   ├── utilities/           # Health check, cleanup, update scripts
│   └── templates/           # settings.json template
├── adapters/                # Platform adapters
│   ├── adapter-interface.yaml  # Abstract contract
│   ├── _adapter-lib.sh      # Shared adapter library
│   ├── claude/              # Claude Code identity adapter
│   └── aider/               # Aider + Ollama adapter
├── language-packs/          # Per-language configurations (7 languages)
├── database-packs/          # Per-database configurations (3 databases)
├── cicd/                    # CI/CD pipeline templates
├── tests/                   # Test suites (10 suites, 268+ tests)
│   ├── suites/              # Individual test scripts
│   └── lib/                 # Test helpers and assertions
├── install.sh               # Main installer (adapter-aware)
├── update.sh                # Safe update mechanism
└── cognitive-core.conf      # Self-managed configuration
```

## Key Rules (survive context compaction)

1. **This IS the framework** — changes here propagate to ALL installed projects via update.sh
2. All hooks MUST follow JSON protocol (stdin/stdout) per `core/hooks/_lib.sh`
3. Skills REQUIRE YAML frontmatter (`name`, `description`, `allowed-tools`) — suite 02 validates
4. Adapters MUST implement the contract in `adapters/adapter-interface.yaml`
5. NEVER break backwards compatibility — existing installations must continue to work
6. Run `bash tests/run-all.sh` before every commit — all suites must pass
7. Git commits: `type(scope): subject` — NO AI references
8. Scopes: hooks, agents, skills, adapters, install, cicd, packs, docs, security

## Code Standards

### Shell Scripts (primary)
- POSIX ERE for regex (no `\s`, `\b`, `\w`) — macOS + Linux compatibility
- `set -euo pipefail` at the top of every script
- Use `_lib.sh` helper functions for JSON parsing and hook responses
- ShellCheck clean (suite 01 validates when shellcheck is installed)

### Python (adapters only)
- Python 3.10+ minimum
- Type hints on function signatures
- argparse for CLI tools
- No external dependencies beyond stdlib (Aider projects already have Python)

### YAML Frontmatter (skills + agents)
```yaml
---
name: skill-name
description: Brief description
user-invocable: true
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---
```

## Component Contracts

### Hooks
- Receive JSON on stdin: `{"tool_name": "...", "tool_input": {...}}`
- Output JSON to stdout for deny: `{"permissionDecision": "deny", "reason": "..."}`
- Silent exit 0 = allow
- Source `_lib.sh` for helpers: `_cc_json_get`, `_cc_json_pretool_deny`, `_cc_load_config`

### Adapters
- Set `_ADAPTER_NAME` and `_ADAPTER_INSTALL_DIR` variables
- Implement 5 required functions: `_adapter_install_hook`, `_adapter_install_agent`, `_adapter_install_skill`, `_adapter_generate_settings`, `_adapter_generate_project_readme`
- Pass `_adapter_validate` contract check

### Tests
- Use `test-helpers.sh` for assertions: `assert_eq`, `assert_contains`, `assert_file_exists`, etc.
- Pattern: `suite_start "NN — Name"` → assertions → `suite_end`
- Output format: `Results: X passed, Y failed, Z skipped (of N)`

## Agents

See `.claude/AGENTS_README.md` for the full agent team documentation.

## Development Workflow

1. Check current branch and status
2. Check project board: issues in **In Progress** column
3. Implement changes following architecture patterns above
4. Run tests: `bash tests/run-all.sh` (all 10 suites must pass)
5. Commit with conventional format: `type(scope): subject`
6. Verify acceptance criteria on related issue

## Related

- **Website**: [multivac42.ai](https://multivac42.ai)
- **TIMS reference**: Scored 4.2/5 in independent workflow audit (Feb 2026)
- **Issue tracker**: [GitHub Issues](https://github.com/mindcockpit-ai/cognitive-core/issues)
