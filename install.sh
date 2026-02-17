#!/bin/bash
# =============================================================================
# cognitive-core install.sh — Interactive bootstrapper
# Installs hooks, agents, skills, language/database packs, and CI/CD pipeline
# into any Claude Code project.
#
# Usage:
#   ./install.sh [project-dir] [--force]
#   ./install.sh /path/to/myproject
#   ./install.sh --force              # overwrite existing installation
# =============================================================================
set -euo pipefail

# ---- Constants ----
CC_VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ---- Helpers ----
info()  { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
err()   { printf "${RED}[x]${RESET} %s\n" "$*" >&2; }
header(){ printf "\n${BOLD}${CYAN}=== %s ===${RESET}\n" "$*"; }

prompt_default() {
    local var_name="$1" prompt_text="$2" default="$3"
    local value
    printf "${BOLD}%s${RESET} [%s]: " "$prompt_text" "$default"
    read -r value
    value="${value:-$default}"
    eval "${var_name}=\"${value}\""
}

prompt_choice() {
    local var_name="$1" prompt_text="$2" options="$3" default="$4"
    printf "${BOLD}%s${RESET} (%s) [%s]: " "$prompt_text" "$options" "$default"
    local value
    read -r value
    value="${value:-$default}"
    eval "${var_name}=\"${value}\""
}

# ---- Parse arguments ----
FORCE=false
PROJECT_DIR=""

for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        -*)      err "Unknown flag: $arg"; exit 1 ;;
        *)       PROJECT_DIR="$arg" ;;
    esac
done

# ---- Resolve project directory ----
if [ -z "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(pwd)"
    printf "${BOLD}Project directory${RESET} [%s]: " "$PROJECT_DIR"
    read -r user_dir
    PROJECT_DIR="${user_dir:-$PROJECT_DIR}"
fi

PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd)" || {
    err "Directory does not exist: $PROJECT_DIR"
    exit 1
}

header "cognitive-core installer v${CC_VERSION}"
info "Project directory: ${PROJECT_DIR}"

# ---- Verify git repo ----
if ! git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    err "Not a git repository: ${PROJECT_DIR}"
    err "Initialize with: git init ${PROJECT_DIR}"
    exit 1
fi
info "Git repository verified."

# ---- Supply chain integrity check (framework source) ----
if git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
    _fw_dirty=$(git -C "$SCRIPT_DIR" status --porcelain 2>/dev/null | grep -c '.' || echo "0")
    _fw_commit=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    if [ "$_fw_dirty" -gt 0 ]; then
        warn "Framework source has ${_fw_dirty} uncommitted change(s). Install may not match a released version."
    fi
    info "Framework commit: ${_fw_commit}"
fi

# ---- Check existing installation ----
VERSION_FILE="${PROJECT_DIR}/.claude/cognitive-core/version.json"
if [ -f "$VERSION_FILE" ] && [ "$FORCE" = false ]; then
    INSTALLED_VER=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$VERSION_FILE" | head -1 | sed 's/.*"version"[[:space:]]*:[[:space:]]*"//;s/"//')
    warn "cognitive-core v${INSTALLED_VER} is already installed."
    warn "Use --force to overwrite, or run update.sh for safe updates."
    exit 1
fi
if [ -f "$VERSION_FILE" ] && [ "$FORCE" = true ]; then
    warn "Force mode: overwriting existing installation."
fi

# ---- Configuration ----
CONF_FILE="${PROJECT_DIR}/cognitive-core.conf"
CONF_ALT="${PROJECT_DIR}/.claude/cognitive-core.conf"

if [ -f "$CONF_FILE" ]; then
    info "Loading configuration: ${CONF_FILE}"
    # shellcheck disable=SC1090
    source "$CONF_FILE"
elif [ -f "$CONF_ALT" ]; then
    info "Loading configuration: ${CONF_ALT}"
    CONF_FILE="$CONF_ALT"
    # shellcheck disable=SC1090
    source "$CONF_ALT"
else
    header "Interactive Setup"
    info "No cognitive-core.conf found. Let's create one."
    echo ""

    # Project identity
    prompt_default CC_PROJECT_NAME "Project name" "$(basename "$PROJECT_DIR")"
    prompt_default CC_PROJECT_DESCRIPTION "Brief description" "A software project"
    prompt_default CC_ORG "Organization/owner" "$(git -C "$PROJECT_DIR" config user.name 2>/dev/null || echo 'my-org')"

    # Language
    prompt_choice CC_LANGUAGE "Primary language" "perl|python|node|java|go|rust|csharp" "python"
    case "$CC_LANGUAGE" in
        perl)   CC_LINT_EXTENSIONS=".pl .pm .t"; CC_LINT_COMMAND='perlcritic $1'; CC_TEST_COMMAND="prove -l t/"; CC_TEST_PATTERN="t/**/*.t" ;;
        python) CC_LINT_EXTENSIONS=".py .pyi"; CC_LINT_COMMAND='ruff check $1'; CC_TEST_COMMAND="pytest"; CC_TEST_PATTERN="tests/**/*.py" ;;
        node)   CC_LINT_EXTENSIONS=".js .ts .tsx"; CC_LINT_COMMAND='eslint $1'; CC_TEST_COMMAND="npm test"; CC_TEST_PATTERN="test/**/*.test.*" ;;
        java)   CC_LINT_EXTENSIONS=".java"; CC_LINT_COMMAND='checkstyle $1'; CC_TEST_COMMAND="mvn test"; CC_TEST_PATTERN="src/test/**/*.java" ;;
        go)     CC_LINT_EXTENSIONS=".go"; CC_LINT_COMMAND='golangci-lint run $1'; CC_TEST_COMMAND="go test ./..."; CC_TEST_PATTERN="**/*_test.go" ;;
        rust)   CC_LINT_EXTENSIONS=".rs"; CC_LINT_COMMAND='cargo clippy -- -D warnings'; CC_TEST_COMMAND="cargo test"; CC_TEST_PATTERN="tests/**/*.rs" ;;
        csharp) CC_LINT_EXTENSIONS=".cs"; CC_LINT_COMMAND='dotnet format --verify-no-changes'; CC_TEST_COMMAND="dotnet test"; CC_TEST_PATTERN="**/*Tests.cs" ;;
        *)      CC_LINT_EXTENSIONS=""; CC_LINT_COMMAND="echo no-lint"; CC_TEST_COMMAND="echo no-tests"; CC_TEST_PATTERN="" ;;
    esac

    # Database
    prompt_choice CC_DATABASE "Database" "oracle|postgresql|mysql|sqlite|none" "none"

    # Architecture
    prompt_choice CC_ARCHITECTURE "Architecture pattern" "ddd|mvc|clean|hexagonal|layered|none" "ddd"
    prompt_default CC_SRC_ROOT "Source root" "src"
    prompt_default CC_TEST_ROOT "Test root" "tests"

    # Agents
    echo ""
    info "Available agents: coordinator reviewer architect tester researcher database security-analyst"
    prompt_default CC_AGENTS "Agents to install" "coordinator reviewer architect tester researcher"
    prompt_choice CC_COORDINATOR_MODEL "Coordinator model" "opus|sonnet" "opus"
    prompt_choice CC_SPECIALIST_MODEL "Specialist model" "opus|sonnet" "sonnet"

    # Skills
    echo ""
    info "Available skills: session-resume session-sync code-review pre-commit fitness"
    info "                  project-status project-board acceptance-verification workflow-analysis test-scaffold tech-intel ctf-pentesting"
    prompt_default CC_SKILLS "Skills to install" "session-resume code-review pre-commit fitness project-status project-board acceptance-verification security-baseline"

    # Hooks
    prompt_default CC_HOOKS "Hooks to enable" "setup-env compact-reminder validate-bash validate-read validate-fetch validate-write post-edit-lint"

    # CI/CD
    prompt_choice CC_ENABLE_CICD "Install CI/CD pipeline?" "true|false" "false"
    if [ "$CC_ENABLE_CICD" = "true" ]; then
        prompt_choice CC_RUNNER_TYPE "Runner type" "self-hosted|github-hosted" "self-hosted"
        prompt_choice CC_MONITORING "Install monitoring stack?" "true|false" "true"
    else
        CC_RUNNER_TYPE="github-hosted"
        CC_MONITORING="false"
    fi

    # Git
    prompt_default CC_MAIN_BRANCH "Main branch" "main"
    prompt_choice CC_COMMIT_FORMAT "Commit format" "conventional|freeform" "conventional"
    prompt_default CC_COMMIT_SCOPES "Commit scopes (space-separated)" "api ui db auth core"

    # Defaults for non-prompted settings
    CC_FORMAT_COMMAND="${CC_FORMAT_COMMAND:-}"
    CC_ENV_VARS="${CC_ENV_VARS:-}"
    CC_COMPACT_RULES="${CC_COMPACT_RULES:-
1. Follow the architecture pattern defined in CLAUDE.md
2. Git commits: type(scope): subject format, no AI references
3. Run lint before every commit
}"
    CC_SECURITY_LEVEL="standard"
    CC_BLOCKED_PATTERNS=""
    CC_ALLOWED_DOMAINS=""
    CC_KNOWN_SAFE_DOMAINS=""
    CC_ENABLE_CLEANUP_CRON="true"
    CC_SESSION_DOCS_DIR="docs"
    CC_SESSION_MAX_AGE_DAYS="30"
    CC_FITNESS_LINT="${CC_FITNESS_LINT:-60}"
    CC_FITNESS_COMMIT="${CC_FITNESS_COMMIT:-80}"
    CC_FITNESS_TEST="${CC_FITNESS_TEST:-85}"
    CC_FITNESS_MERGE="${CC_FITNESS_MERGE:-90}"
    CC_FITNESS_DEPLOY="${CC_FITNESS_DEPLOY:-95}"
    CC_RUNNER_NODES="${CC_RUNNER_NODES:-1}"
    CC_RUNNER_LABELS="${CC_RUNNER_LABELS:-self-hosted,linux,docker}"
    CC_AGENT_TEAMS="false"
    # shellcheck disable=SC2034
    CC_MCP_SERVERS="context7"
    CC_UPDATE_AUTO_CHECK="true"
    CC_UPDATE_CHECK_INTERVAL="7"

    # Write config file
    info "Writing configuration to ${CONF_FILE}"
    cat > "$CONF_FILE" << CONFEOF
#!/bin/false
# cognitive-core.conf — Project Configuration
# Generated by install.sh on $(date +%Y-%m-%d)

# ===== PROJECT IDENTITY =====
CC_PROJECT_NAME="${CC_PROJECT_NAME}"
CC_PROJECT_DESCRIPTION="${CC_PROJECT_DESCRIPTION}"
CC_ORG="${CC_ORG}"

# ===== LANGUAGE & STACK =====
CC_LANGUAGE="${CC_LANGUAGE}"
CC_LINT_EXTENSIONS="${CC_LINT_EXTENSIONS}"
CC_LINT_COMMAND="${CC_LINT_COMMAND}"
CC_FORMAT_COMMAND="${CC_FORMAT_COMMAND}"
CC_TEST_COMMAND="${CC_TEST_COMMAND}"
CC_TEST_PATTERN="${CC_TEST_PATTERN}"

# ===== DATABASE =====
CC_DATABASE="${CC_DATABASE}"

# ===== ARCHITECTURE =====
CC_ARCHITECTURE="${CC_ARCHITECTURE}"
CC_SRC_ROOT="${CC_SRC_ROOT}"
CC_TEST_ROOT="${CC_TEST_ROOT}"

# ===== AGENTS =====
CC_AGENTS="${CC_AGENTS}"
CC_COORDINATOR_MODEL="${CC_COORDINATOR_MODEL}"
CC_SPECIALIST_MODEL="${CC_SPECIALIST_MODEL}"

# ===== SKILLS =====
CC_SKILLS="${CC_SKILLS}"

# ===== HOOKS =====
CC_HOOKS="${CC_HOOKS}"

# ===== SECURITY =====
CC_SECURITY_LEVEL="${CC_SECURITY_LEVEL}"
CC_BLOCKED_PATTERNS="${CC_BLOCKED_PATTERNS}"
CC_ALLOWED_DOMAINS="${CC_ALLOWED_DOMAINS}"
CC_KNOWN_SAFE_DOMAINS="${CC_KNOWN_SAFE_DOMAINS}"

# ===== GIT =====
CC_MAIN_BRANCH="${CC_MAIN_BRANCH}"
CC_COMMIT_FORMAT="${CC_COMMIT_FORMAT}"
CC_COMMIT_SCOPES="${CC_COMMIT_SCOPES}"

# ===== CI/CD =====
CC_ENABLE_CICD="${CC_ENABLE_CICD}"
CC_RUNNER_TYPE="${CC_RUNNER_TYPE}"
CC_MONITORING="${CC_MONITORING}"
CC_FITNESS_LINT="${CC_FITNESS_LINT}"
CC_FITNESS_COMMIT="${CC_FITNESS_COMMIT}"
CC_FITNESS_TEST="${CC_FITNESS_TEST}"
CC_FITNESS_MERGE="${CC_FITNESS_MERGE}"
CC_FITNESS_DEPLOY="${CC_FITNESS_DEPLOY}"

# ===== HORIZONTAL SCALING =====
CC_RUNNER_NODES="${CC_RUNNER_NODES}"
CC_RUNNER_LABELS="${CC_RUNNER_LABELS}"

# ===== CONNECTED PROJECTS =====
CC_UPDATE_AUTO_CHECK="${CC_UPDATE_AUTO_CHECK}"
CC_UPDATE_CHECK_INTERVAL="${CC_UPDATE_CHECK_INTERVAL}"

# ===== CONTEXT MANAGEMENT =====
CC_ENABLE_CLEANUP_CRON="${CC_ENABLE_CLEANUP_CRON}"
CC_SESSION_DOCS_DIR="${CC_SESSION_DOCS_DIR}"
CC_SESSION_MAX_AGE_DAYS="${CC_SESSION_MAX_AGE_DAYS}"
CONFEOF
fi

# ---- Re-source config to ensure all variables are set ----
# shellcheck disable=SC1090
source "$CONF_FILE"

# ---- Create directory structure ----
header "Creating directory structure"

CLAUDE_DIR="${PROJECT_DIR}/.claude"
mkdir -p "${CLAUDE_DIR}/hooks"
mkdir -p "${CLAUDE_DIR}/agents"
mkdir -p "${CLAUDE_DIR}/skills"
mkdir -p "${CLAUDE_DIR}/cognitive-core"
info "Created .claude/ directory tree."

# ---- Agent name mapping ----
agent_file_for() {
    case "$1" in
        coordinator) echo "project-coordinator.md" ;;
        reviewer)    echo "code-standards-reviewer.md" ;;
        architect)   echo "solution-architect.md" ;;
        tester)      echo "test-specialist.md" ;;
        researcher)  echo "research-analyst.md" ;;
        database)          echo "database-specialist.md" ;;
        security-analyst)  echo "security-analyst.md" ;;
        *) echo "" ;;
    esac
}

# ---- Install hooks ----
header "Installing hooks"

# Always copy the shared library first
cp "${SCRIPT_DIR}/core/hooks/_lib.sh" "${CLAUDE_DIR}/hooks/_lib.sh"
info "Installed _lib.sh (shared hook library)"

for hook in ${CC_HOOKS:-}; do
    src="${SCRIPT_DIR}/core/hooks/${hook}.sh"
    if [ -f "$src" ]; then
        cp "$src" "${CLAUDE_DIR}/hooks/${hook}.sh"
        info "Installed hook: ${hook}"
    else
        warn "Hook not found: ${hook} (skipped)"
    fi
done

# ---- Install utilities ----
header "Installing utilities"

for util in check-update.sh context-cleanup.sh health-check.sh; do
    UTIL_SRC="${SCRIPT_DIR}/core/utilities/${util}"
    if [ -f "$UTIL_SRC" ]; then
        cp "$UTIL_SRC" "${CLAUDE_DIR}/cognitive-core/${util}"
        chmod +x "${CLAUDE_DIR}/cognitive-core/${util}"
        info "Installed utility: ${util}"
    fi
done

# ---- Install agents ----
header "Installing agents"

INSTALLED_AGENTS=""
for agent in ${CC_AGENTS:-}; do
    filename=$(agent_file_for "$agent")
    if [ -z "$filename" ]; then
        warn "Unknown agent: ${agent} (skipped)"
        continue
    fi
    src="${SCRIPT_DIR}/core/agents/${filename}"
    if [ -f "$src" ]; then
        cp "$src" "${CLAUDE_DIR}/agents/${filename}"
        INSTALLED_AGENTS="${INSTALLED_AGENTS} ${agent}"
        info "Installed agent: ${agent} (${filename})"
    else
        warn "Agent file not found: ${filename} (skipped)"
    fi
done

# ---- Install skills ----
header "Installing skills"

# Skill name to directory mapping (direct 1:1)
for skill in ${CC_SKILLS:-}; do
    src="${SCRIPT_DIR}/core/skills/${skill}"
    if [ -d "$src" ]; then
        mkdir -p "${CLAUDE_DIR}/skills/${skill}"
        cp -R "${src}/"* "${CLAUDE_DIR}/skills/${skill}/" 2>/dev/null || true
        info "Installed skill: ${skill}"
    else
        warn "Skill not found: ${skill} (skipped)"
    fi
done

# ---- Install language pack ----
if [ -n "${CC_LANGUAGE:-}" ] && [ "$CC_LANGUAGE" != "none" ]; then
    header "Installing language pack: ${CC_LANGUAGE}"
    LANG_DIR="${SCRIPT_DIR}/language-packs/${CC_LANGUAGE}"
    if [ -d "$LANG_DIR" ]; then
        # Copy language-specific skills
        if [ -d "${LANG_DIR}/skills" ]; then
            for skill_dir in "${LANG_DIR}/skills/"*/; do
                if [ -d "$skill_dir" ]; then
                    skill_name=$(basename "$skill_dir")
                    mkdir -p "${CLAUDE_DIR}/skills/${skill_name}"
                    cp -R "${skill_dir}"* "${CLAUDE_DIR}/skills/${skill_name}/" 2>/dev/null || true
                    info "Installed language skill: ${skill_name}"
                fi
            done
        fi
        # Copy any additional language pack files (templates, configs, etc.)
        for item in "${LANG_DIR}/"*; do
            base=$(basename "$item")
            if [ "$base" != "skills" ] && [ -f "$item" ]; then
                cp "$item" "${CLAUDE_DIR}/${base}"
                info "Installed language file: ${base}"
            fi
        done
    else
        warn "Language pack directory not found: ${CC_LANGUAGE} (skipped)"
    fi
fi

# ---- Install database pack ----
if [ -n "${CC_DATABASE:-}" ] && [ "$CC_DATABASE" != "none" ]; then
    header "Installing database pack: ${CC_DATABASE}"
    DB_DIR="${SCRIPT_DIR}/database-packs/${CC_DATABASE}"
    if [ -d "$DB_DIR" ]; then
        # Copy database-specific skills
        if [ -d "${DB_DIR}/skills" ]; then
            for skill_dir in "${DB_DIR}/skills/"*/; do
                if [ -d "$skill_dir" ]; then
                    skill_name=$(basename "$skill_dir")
                    mkdir -p "${CLAUDE_DIR}/skills/${skill_name}"
                    cp -R "${skill_dir}"* "${CLAUDE_DIR}/skills/${skill_name}/" 2>/dev/null || true
                    info "Installed database skill: ${skill_name}"
                fi
            done
        fi
        # Copy any additional database pack files
        for item in "${DB_DIR}/"*; do
            base=$(basename "$item")
            if [ "$base" != "skills" ] && [ -f "$item" ]; then
                cp "$item" "${CLAUDE_DIR}/${base}"
                info "Installed database file: ${base}"
            fi
        done
    else
        warn "Database pack directory not found: ${CC_DATABASE} (skipped)"
    fi
fi

# ---- Generate settings.json ----
header "Generating settings.json"

SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
if [ -f "${SCRIPT_DIR}/core/templates/settings.json.tmpl" ]; then
    sed \
        -e "s|{{CC_PROJECT_NAME}}|${CC_PROJECT_NAME:-project}|g" \
        -e "s|{{CC_LANGUAGE}}|${CC_LANGUAGE:-none}|g" \
        -e "s|{{CC_ARCHITECTURE}}|${CC_ARCHITECTURE:-none}|g" \
        -e "s|{{CC_MAIN_BRANCH}}|${CC_MAIN_BRANCH:-main}|g" \
        -e "s|{{CC_LINT_COMMAND}}|${CC_LINT_COMMAND:-echo no-lint}|g" \
        -e "s|{{CC_TEST_COMMAND}}|${CC_TEST_COMMAND:-echo no-tests}|g" \
        -e "s|{{CC_AGENT_TEAMS}}|${CC_AGENT_TEAMS:-false}|g" \
        "${SCRIPT_DIR}/core/templates/settings.json.tmpl" > "$SETTINGS_FILE"
    info "Generated settings.json from template."
else
    # Generate a minimal settings.json directly
    cat > "$SETTINGS_FILE" << SETEOF
{
  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(${CC_LINT_COMMAND:-echo no-lint})",
      "Bash(${CC_TEST_COMMAND:-echo no-tests})"
    ],
    "deny": []
  },
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume",
        "hooks": [
          ".claude/hooks/setup-env.sh"
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          ".claude/hooks/validate-bash.sh"
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          ".claude/hooks/post-edit-lint.sh"
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "compact",
        "hooks": [
          ".claude/hooks/compact-reminder.sh"
        ]
      }
    ]
  }
}
SETEOF
    info "Generated settings.json (no template found, used defaults)."
fi

# ---- Generate CLAUDE.md scaffold ----
CLAUDEMD="${PROJECT_DIR}/CLAUDE.md"
if [ ! -f "$CLAUDEMD" ] || [ "$FORCE" = true ]; then
    header "Generating CLAUDE.md scaffold"
    cat > "$CLAUDEMD" << 'CLAUDEEOF'
# Project Development Guide

## Quick Reference

| Item | Value |
|------|-------|
CLAUDEEOF

    cat >> "$CLAUDEMD" << CLAUDEEOF
| **Project** | ${CC_PROJECT_NAME} |
| **Language** | ${CC_LANGUAGE} |
| **Architecture** | ${CC_ARCHITECTURE} |
| **Database** | ${CC_DATABASE} |
| **Main Branch** | ${CC_MAIN_BRANCH} |
| **Test Command** | \`${CC_TEST_COMMAND}\` |
| **Lint Command** | \`${CC_LINT_COMMAND}\` |

## Architecture

Pattern: **${CC_ARCHITECTURE}**
Source root: \`${CC_SRC_ROOT}\`
Test root: \`${CC_TEST_ROOT}\`

<!-- TODO: Document your architecture layers and patterns here -->

## Code Standards

- Follow ${CC_LANGUAGE} community best practices
- Run lint before every commit
- All new code must have tests
- Git commits: \`type(scope): subject\` (${CC_COMMIT_FORMAT} format)
- NO AI/tool references in commit messages

## Key Rules

<!-- TODO: Add your project's critical rules here -->
<!-- These survive context compaction and are always visible -->

1. Follow the architecture pattern defined above
2. Use parameterized queries for all database operations
3. Run lint before every commit

## Agents

See \`.claude/AGENTS_README.md\` for the agent team documentation.

## Development Workflow

1. Check current branch and status
2. Implement changes following architecture pattern
3. Run tests: \`${CC_TEST_COMMAND}\`
4. Run lint: \`${CC_LINT_COMMAND}\`
5. Commit with conventional format
CLAUDEEOF
    info "Generated CLAUDE.md scaffold."
else
    info "CLAUDE.md already exists (preserved)."
fi

# ---- Generate AGENTS_README.md ----
header "Generating AGENTS_README.md"

AGENTS_README="${CLAUDE_DIR}/AGENTS_README.md"
cat > "$AGENTS_README" << 'AGENTSEOF'
# Agent Team Architecture

## Hub-and-Spoke Model

The agent team follows a hub-and-spoke pattern where the **project-coordinator**
acts as the central orchestrator, delegating to specialist agents based on task type.

```
                         ┌───────────────────┐
                         │       USER        │
                         │    (Developer)    │
                         └─────────┬─────────┘
                                   │
                                   ▼
┌──────────────────────────────────────────────────────────────┐
│                                                              │
│                  PROJECT-COORDINATOR (Hub)                   │
│                  Smart Orchestrator / Opus                   │
│                                                              │
│  • Analyze incoming requests                                 │
│  • Route to appropriate specialist                           │
│  • Coordinate multi-agent workflows                          │
│  • Synthesize results into unified response                  │
│  • Manage project board and sprint planning                  │
│                                                              │
└────────┬──────────┬──────────┬──────────┬──────────┬─────────┘
         │          │          │          │          │
         ▼          ▼          ▼          ▼          ▼
   ┌──────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
   │ solution │ │  code  │ │  test  │ │research│ │database│
   │ architect│ │reviewer│ │  spec  │ │ analyst│ │  spec  │
   │  (Opus)  │ │(Sonnet)│ │(Sonnet)│ │ (Opus) │ │ (Opus) │
   └──────────┘ └────────┘ └────────┘ └────────┘ └────────┘
```

## Agent Catalog

### project-coordinator (Hub)
- **File**: `project-coordinator.md` | **Model**: opus
- **Role**: Smart orchestrator — analyzes requests and delegates to specialists
- **Use when**: Project planning, multi-agent coordination, sprint planning, risk assessment, TODO creation
- **Don't use for**: Simple single-task requests, direct code implementation, single-domain tasks

### solution-architect
- **File**: `solution-architect.md` | **Model**: opus
- **Role**: Business workflows, architectural decisions, requirements analysis
- **Use when**: New feature design, workflow implementation, integration decisions, technical feasibility
- **Don't use for**: Code fixes, code review, test creation, DB performance, pure research

### code-standards-reviewer
- **File**: `code-standards-reviewer.md` | **Model**: sonnet
- **Role**: Code review, standards compliance, architecture pattern verification
- **Use when**: After code implementation, PR reviews, refactoring validation, standards verification
- **Don't use for**: Writing new code, business analysis, test creation, research
- **Restrictions**: No WebFetch, No WebSearch (reviews code, not web)

### test-specialist
- **File**: `test-specialist.md` | **Model**: sonnet
- **Role**: Unit/integration/UI tests, coverage analysis, QA strategy
- **Use when**: New code needs tests, test failures, coverage gaps, test refactoring
- **Don't use for**: Code implementation without test focus, business analysis, code review

### research-analyst
- **File**: `research-analyst.md` | **Model**: opus
- **Role**: External research, library evaluation, technology assessment, best practices
- **Use when**: Unknown technologies, error investigation, library selection, industry patterns
- **Don't use for**: Internal code questions, code review, test creation
- **Restrictions**: No Write, No Edit (research only, does not modify code)

### database-specialist
- **File**: `database-specialist.md` | **Model**: opus
- **Role**: Database optimization, query tuning, bulk operations, index analysis
- **Use when**: Slow queries, import performance, database design, bulk data operations
- **Don't use for**: Simple CRUD, business logic, code review without performance concerns

### security-analyst (optional)
- **File**: `security-analyst.md` | **Model**: opus
- **Role**: Offensive security, CTF mentoring, vulnerability analysis, forensic investigation
- **Use when**: Pentest, CTF challenges, vulnerability scanning, security code review, breach analysis
- **Don't use for**: General code review, business analysis, non-security tasks

## Keyword → Agent Routing

| Keywords in Request | Route To |
|---------------------|----------|
| "implement feature", "new workflow", "approval process", "design" | solution-architect |
| "review code", "check standards", "CLAUDE.md compliance", "refactor" | code-standards-reviewer |
| "write tests", "test coverage", "failing test", "QA" | test-specialist |
| "research", "best practice", "which library", "error investigation" | research-analyst |
| "slow query", "performance", "bulk import", "database", "index" | database-specialist |
| "plan project", "create TODO", "sprint", "coordinate", "board" | project-coordinator |
| "pentest", "CTF", "vulnerability", "exploit", "security scan" | security-analyst |

## Delegation Flow

1. Request arrives at **project-coordinator**
2. Coordinator analyzes and identifies required expertise
3. Delegates to appropriate specialist(s) with clear scope
4. Specialist completes work and reports back
5. Coordinator synthesizes results
6. **code-standards-reviewer** performs final quality gate (**MANDATORY** for code changes)

## Escalation Paths

```
code-standards-reviewer finds performance issue  → database-specialist
test-specialist finds architectural flaw          → solution-architect
database-specialist needs research                → research-analyst
security-analyst finds systemic vulnerability     → project-coordinator
Any agent blocked or needs cross-cutting work     → project-coordinator
```

## Mandatory Quality Gate

Every code change MUST include a code-standards-reviewer pass before completion:

```
[ ] Implementation tasks...
[ ] Unit tests (test-specialist)
[ ] Integration tests (test-specialist)
[ ] Code Standards Review (code-standards-reviewer) ← MANDATORY
[ ] Automated lint verification ← MANDATORY
[ ] Documentation update
```
AGENTSEOF
info "Generated AGENTS_README.md."

# ---- CI/CD Pipeline ----
if [ "${CC_ENABLE_CICD:-false}" = "true" ]; then
    header "Installing CI/CD pipeline"

    # Workflows
    WORKFLOW_DIR="${PROJECT_DIR}/.github/workflows"
    mkdir -p "$WORKFLOW_DIR"
    if [ -d "${SCRIPT_DIR}/cicd/workflows" ]; then
        cp "${SCRIPT_DIR}/cicd/workflows/"* "$WORKFLOW_DIR/" 2>/dev/null || true
        info "Installed GitHub Actions workflows."
    fi

    # Docker
    DOCKER_DIR="${PROJECT_DIR}/cicd/docker"
    mkdir -p "$DOCKER_DIR"
    if [ -d "${SCRIPT_DIR}/cicd/docker" ]; then
        cp "${SCRIPT_DIR}/cicd/docker/"* "$DOCKER_DIR/" 2>/dev/null || true
        info "Installed Docker configurations."
    fi

    # CI/CD scripts
    CICD_SCRIPTS="${PROJECT_DIR}/cicd/scripts"
    mkdir -p "$CICD_SCRIPTS"
    if [ -d "${SCRIPT_DIR}/cicd/scripts" ]; then
        cp "${SCRIPT_DIR}/cicd/scripts/"* "$CICD_SCRIPTS/" 2>/dev/null || true
        info "Installed CI/CD scripts."
    fi

    # Monitoring
    if [ "${CC_MONITORING:-false}" = "true" ]; then
        MON_DIR="${PROJECT_DIR}/cicd/monitoring"
        mkdir -p "$MON_DIR"
        if [ -d "${SCRIPT_DIR}/cicd/monitoring" ]; then
            cp -R "${SCRIPT_DIR}/cicd/monitoring/"* "$MON_DIR/" 2>/dev/null || true
            info "Installed monitoring stack (Prometheus, Grafana, Alertmanager)."
        fi
    fi

    # Kubernetes
    K8S_DIR="${PROJECT_DIR}/cicd/k8s"
    mkdir -p "$K8S_DIR"
    if [ -d "${SCRIPT_DIR}/cicd/k8s" ]; then
        cp -R "${SCRIPT_DIR}/cicd/k8s/"* "$K8S_DIR/" 2>/dev/null || true
        info "Installed Kubernetes manifests."
    fi

    # Generate .env.template for the project
    ENV_TMPL="${PROJECT_DIR}/cicd/monitoring/.env.template"
    if [ -f "${SCRIPT_DIR}/cicd/monitoring/.env.template" ] && [ ! -f "$ENV_TMPL" ]; then
        cp "${SCRIPT_DIR}/cicd/monitoring/.env.template" "$ENV_TMPL"
        sed -i.bak "s|PROJECT_NAME=myproject|PROJECT_NAME=${CC_PROJECT_NAME}|g" "$ENV_TMPL" 2>/dev/null || \
            sed -i '' "s|PROJECT_NAME=myproject|PROJECT_NAME=${CC_PROJECT_NAME}|g" "$ENV_TMPL"
        rm -f "${ENV_TMPL}.bak"
        info "Generated .env.template with project name."
    fi
fi

# ---- Write version manifest ----
header "Writing version manifest"

MANIFEST_DIR="${CLAUDE_DIR}/cognitive-core"
mkdir -p "$MANIFEST_DIR"

# Build installed files list for checksum tracking
INSTALLED_FILES="[]"
if command -v python3 &>/dev/null; then
    # Use python for proper JSON array construction
    INSTALLED_FILES=$(find "${CLAUDE_DIR}" -type f -not -path "*/cognitive-core/*" | sort | python3 -c "
import sys, json, hashlib, os
files = []
project = '${PROJECT_DIR}'
for line in sys.stdin:
    path = line.strip()
    if not path:
        continue
    rel = os.path.relpath(path, project)
    try:
        with open(path, 'rb') as f:
            sha = hashlib.sha256(f.read()).hexdigest()
        files.append({'path': rel, 'sha256': sha})
    except:
        pass
print(json.dumps(files, indent=4))
")
fi

cat > "$VERSION_FILE" << VEOF
{
    "version": "${CC_VERSION}",
    "installed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "project": "${CC_PROJECT_NAME}",
    "language": "${CC_LANGUAGE}",
    "database": "${CC_DATABASE:-none}",
    "architecture": "${CC_ARCHITECTURE}",
    "agents": "${CC_AGENTS}",
    "skills": "${CC_SKILLS}",
    "hooks": "${CC_HOOKS}",
    "cicd": ${CC_ENABLE_CICD:-false},
    "monitoring": ${CC_MONITORING:-false},
    "source": "${SCRIPT_DIR}",
    "files": ${INSTALLED_FILES}
}
VEOF
info "Wrote version manifest: ${VERSION_FILE}"

# ---- Make all scripts executable ----
header "Setting permissions"

find "${CLAUDE_DIR}/hooks" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
if [ "${CC_ENABLE_CICD:-false}" = "true" ]; then
    find "${PROJECT_DIR}/cicd/scripts" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
fi
info "Made all shell scripts executable."

# ---- Summary ----
header "Installation complete"

echo ""
printf "${BOLD}Installed components:${RESET}\n"
printf "  Hooks:    %s\n" "${CC_HOOKS:-none}"
printf "  Agents:   %s\n" "${CC_AGENTS:-none}"
printf "  Skills:   %s\n" "${CC_SKILLS:-none}"
printf "  Language:  %s\n" "${CC_LANGUAGE:-none}"
printf "  Database:  %s\n" "${CC_DATABASE:-none}"
printf "  CI/CD:     %s\n" "${CC_ENABLE_CICD:-false}"
printf "  Monitoring:%s\n" "${CC_MONITORING:-false}"
echo ""

header "Next steps"
echo ""
echo "  1. Review and customize CLAUDE.md for your project"
echo "  2. Review .claude/settings.json hook configuration"
echo "  3. Review .claude/AGENTS_README.md for agent team documentation"
echo "  4. Run context health check:"
printf "     ${CYAN}bash .claude/cognitive-core/health-check.sh${RESET}\n"
echo "  5. Commit the .claude/ directory and CLAUDE.md to git:"
echo ""
printf "     ${CYAN}git add .claude/ CLAUDE.md cognitive-core.conf${RESET}\n"
printf "     ${CYAN}git commit -m \"chore: install cognitive-core v${CC_VERSION}\"${RESET}\n"
echo ""
echo "  6. (Optional) Set up weekly context cleanup cron:"
printf "     ${CYAN}bash .claude/cognitive-core/context-cleanup.sh --setup-cron${RESET}\n"
echo ""
if [ "${CC_ENABLE_CICD:-false}" = "true" ]; then
    echo "  4. Copy and configure cicd/monitoring/.env.template:"
    printf "     ${CYAN}cp cicd/monitoring/.env.template cicd/monitoring/.env${RESET}\n"
    echo "     Edit .env with real credentials (never commit .env)"
    echo ""
    echo "  5. Start monitoring stack:"
    printf "     ${CYAN}cd cicd/docker && docker compose -f docker-compose.monitoring.yml up -d${RESET}\n"
    echo ""
fi
echo "  Start a Claude Code session to verify hooks load correctly."
echo ""
info "Done. Happy coding with cognitive-core."
