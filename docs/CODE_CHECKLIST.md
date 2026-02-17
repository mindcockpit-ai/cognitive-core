# cognitive-core Code Checklist

Comprehensive conventions for developing cognitive-core itself and for child projects that adopt the framework.

## Framework Development (cognitive-core repo)

### Shell Scripts

| Rule | Severity | Example |
|------|----------|---------|
| `set -euo pipefail` in every script | ERROR | First line after shebang |
| ShellCheck clean (`shellcheck script.sh`) | ERROR | No warnings or errors |
| Source `_lib.sh` before using `_cc_*` functions | ERROR | `source "${SCRIPT_DIR}/_lib.sh"` |
| Use `_cc_json_get` for JSON parsing, not raw grep/sed | WARN | `echo "$JSON" \| _cc_json_get ".field"` |
| Cross-platform compatibility (macOS + Linux) | ERROR | Use `[[:space:]]` not `\s` in grep |
| Use `_cc_compute_sha256` not inline sha256 | WARN | Defined in `_lib.sh` |
| Quote all variable expansions | ERROR | `"${var}"` not `$var` |
| Use `local` for function variables | WARN | `local result=""` |

### Hook Protocol

| Rule | Severity | Details |
|------|----------|---------|
| Hooks read JSON from stdin | ERROR | `tool_name`, `tool_input` fields |
| PreToolUse outputs: `allow` (exit 0, no JSON), `deny`, or `ask` | ERROR | Use `_cc_json_pretool_deny` / `_cc_json_pretool_ask` |
| PostToolUse outputs: non-blocking context only | ERROR | Use `_cc_json_posttool_context` |
| SessionStart outputs: `additionalContext` | ERROR | Use `_cc_json_session_context` |
| Hooks MUST NOT crash the framework | ERROR | Use `_cc_guard_run` for isolation |
| Log security events via `_cc_security_log` | WARN | Level: DENY, WARN, INFO, ASK, ERROR |

### YAML Frontmatter (Skills & Agents)

| Rule | Severity | Details |
|------|----------|---------|
| Skills: `name` and `description` required | ERROR | In `---` delimited YAML block |
| Agents: `name`, `description`, `model` required | ERROR | model: opus or sonnet |
| Skills: max 500 lines for SKILL.md | WARN | Split to `references/` subdirectory |
| Agents: max 300 lines | WARN | Keep focused on role definition |
| Agent `disallowedTools` for least-privilege | WARN | Restrict tools not needed for role |

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Hook scripts | `kebab-case.sh` | `validate-bash.sh` |
| Agent files | `kebab-case.md` | `project-coordinator.md` |
| Skill directories | `kebab-case/` | `security-baseline/` |
| Config variables | `CC_UPPER_SNAKE` | `CC_SECURITY_LEVEL` |
| Bash functions | `_cc_snake_case` | `_cc_compute_sha256` |
| Test suites | `NN-kebab-case.sh` | `06-security-hooks.sh` |
| Documentation | `UPPER_SNAKE.md` | `CODE_CHECKLIST.md` |

### File Organization

```
core/
├── hooks/          # Shell scripts, sourced by _lib.sh
│   ├── _lib.sh     # Shared library (always installed first)
│   ├── setup-env.sh
│   ├── compact-reminder.sh
│   ├── validate-bash.sh
│   ├── validate-read.sh
│   ├── validate-fetch.sh
│   ├── validate-write.sh
│   └── post-edit-lint.sh
├── agents/         # Markdown agent definitions
├── skills/         # Skill directories with SKILL.md
├── templates/      # settings.json.tmpl, CLAUDE.md.tmpl
└── utilities/      # Standalone helper scripts
tests/
├── run-all.sh      # Master test runner
├── lib/            # Test helpers, assertions
└── suites/         # Numbered test suites (01-NN)
docs/               # Framework documentation
```

### Common Mistakes — Framework

| Mistake | Correct Pattern |
|---------|----------------|
| Using `\s` in grep on macOS | Use `[[:space:]]` (POSIX character class) |
| `grep` pattern starting with `-` | Use `grep -e '-----BEGIN...'` (explicit pattern flag) |
| Setting `CC_PROJECT_DIR` directly | Set `CLAUDE_PROJECT_DIR` — `_lib.sh` derives `CC_PROJECT_DIR` from it |
| Silent hook failures (return 0 always) | Log error via `_cc_security_log` before returning 0 |
| Hardcoded paths in tests | Use `$SCRIPT_DIR` or temp directories |
| Missing `|| true` after grep in pipes | grep exits 1 on no match; use `|| true` or `|| echo "0"` |
| `eval` for JSON parsing | Use `jq` with `_cc_json_get` fallback |

---

## Child Project Standards

These conventions apply to projects that install cognitive-core.

### Architecture Pattern Compliance

The architecture defined in `CC_ARCHITECTURE` dictates the layering:

| Pattern | Layers (top → bottom) | Rule |
|---------|----------------------|------|
| **ddd** | Controller → Service → Repository → Mapper → Domain | Domain has NO dependencies |
| **mvc** | Controller → Model → View | Models contain business logic |
| **clean** | Adapters → Use Cases → Entities | Dependency rule: inward only |
| **hexagonal** | Adapters → Ports → Domain | Ports define interfaces |
| **layered** | Presentation → Business → Data | Each layer calls only the one below |

### Git Commit Standards

```
type(scope): subject

Types: feat|fix|docs|style|refactor|test|chore
Scope: from CC_COMMIT_SCOPES
Subject: imperative mood, no period, <72 chars
```

**Mandatory rules:**
- NO AI/Claude/tool references in commit messages
- NO co-authored-by AI headers
- Professional codebase only

### Code Quality Gates

| Gate | Threshold | When |
|------|-----------|------|
| Lint | CC_FITNESS_LINT (60%) | Every file save |
| Commit | CC_FITNESS_COMMIT (80%) | Pre-commit |
| Test | CC_FITNESS_TEST (85%) | PR creation |
| Merge | CC_FITNESS_MERGE (90%) | Before merge |
| Deploy | CC_FITNESS_DEPLOY (95%) | Production release |

### Security Checklist

- [ ] No secrets in code (validate-write.sh catches: AWS keys, PEM, API tokens, passwords)
- [ ] No sensitive file reads outside project (validate-read.sh blocks: shadow, ssh keys, aws creds)
- [ ] No exfiltration patterns in Bash (validate-bash.sh catches: curl -d, pipe-to-shell, encoded exec)
- [ ] Parameterized queries for all database operations
- [ ] Input validation at system boundaries
- [ ] Error messages don't leak internal details

### Agent Usage Checklist

Before delegating to an agent:
- [ ] Identified the right specialist (see AGENTS_README.md routing table)
- [ ] Defined clear scope and expected deliverable
- [ ] Verified agent has necessary tool access (check `disallowedTools`)
- [ ] Code review scheduled after implementation (code-standards-reviewer is MANDATORY)

### Context Budget

| Component | Max Size | Enforcement |
|-----------|----------|-------------|
| SKILL.md files | 500 lines | `health-check.sh` warns |
| Agent definitions | 300 lines | `health-check.sh` warns |
| CLAUDE.md | 400 lines | `health-check.sh` warns |
| Auto-load context total | <100KB | `health-check.sh` estimates |

**Tips:**
- Split large skills into `SKILL.md` (rules) + `references/` (details read on demand)
- Use `disable-model-invocation: true` for workflow-only skills (not auto-loaded)
- Keep CLAUDE.md focused: quick reference table + critical rules + agent routing

### Testing Standards

- Tests mirror source structure
- Test file naming: `*_test.*`, `*.test.*`, `*.spec.*`, `*Tests.*`
- AAA pattern: Arrange, Act, Assert
- Independent and repeatable (no test interdependencies)
- Mock external services (database, APIs)
- Coverage targets: defined by CC_FITNESS_* thresholds

### Session Document Format

```markdown
# Project Session Summary - YYYY-MM-DD

## Session Overview
[1-2 sentence summary]

## Completed Work
### 1. [Topic]
**Status**: Complete/In Progress
[Details, code references, decisions]

## Files Changed
### New Files
### Modified Files

## Key Decisions
1. [Decision with rationale]

## Next Session TODO
### Priority 1: [Most important]
### Priority 2: [Secondary]
```

Session documents older than `CC_SESSION_MAX_AGE_DAYS` (default 30) are auto-archived by `context-cleanup.sh`.
