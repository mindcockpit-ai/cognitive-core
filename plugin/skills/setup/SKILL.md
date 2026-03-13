---
name: setup
description: Initialize cognitive-core configuration for this project. Creates cognitive-core.conf with project-specific settings.
user-invocable: true
allowed-tools: [Bash, Read, Write, Edit, Glob, Grep]
---

# cognitive-core Setup — Project Configuration Wizard

Initialize cognitive-core for the current project by generating a `cognitive-core.conf` file.

## Pre-flight Checks

1. Check if `cognitive-core.conf` already exists at the project root. If yes, ask the user if they want to reconfigure or keep existing.
2. Check if `.claude/hooks/` directory exists (legacy installation). If yes, warn:
   > "Detected legacy cognitive-core installation in .claude/hooks/. The plugin provides hooks natively — you can safely remove .claude/hooks/, .claude/agents/, and .claude/skills/ directories to avoid duplicate hook execution."

## Configuration Steps

Gather the following from the user conversationally. Use sensible defaults based on project analysis.

### 1. Project Identity
- **CC_PROJECT_NAME**: Detect from `package.json`, `pom.xml`, `Cargo.toml`, `pyproject.toml`, or directory name
- **CC_PROJECT_DESCRIPTION**: Ask or detect from README
- **CC_ORG**: Detect from git remote URL

### 2. Language & Stack
Detect primary language by scanning file extensions. Present finding and ask to confirm:
- **CC_LANGUAGE**: python, node, react, angular, spring-boot, java, go, rust, perl, csharp
- **CC_LINT_COMMAND**: Suggest based on language (ruff, eslint, go vet, etc.)
- **CC_TEST_COMMAND**: Suggest based on language (pytest, jest, go test, etc.)

### 3. Database
- **CC_DATABASE**: Detect from dependencies (psycopg2 → postgresql, mysql-connector → mysql, cx_Oracle → oracle) or ask. Default: none

### 4. Architecture
- **CC_ARCHITECTURE**: Detect from directory structure (layered, hexagonal, mvc, microservice, monolith). Default: layered
- **CC_SRC_ROOT**: Detect (src/, lib/, app/)
- **CC_TEST_ROOT**: Detect (tests/, test/, __tests__/)

### 5. Security Level
Explain the three levels and ask:
- **minimal**: Blocks only critical destructive commands (rm -rf /, DROP DATABASE)
- **standard** (recommended): Blocks destructive commands + sensitive file reads + untrusted domains
- **strict**: Blocks everything not explicitly allowed. Best for production/compliance environments.

### 6. Git
- **CC_MAIN_BRANCH**: Detect from git (main or master)
- **CC_COMMIT_FORMAT**: Default to conventional

## Output

Generate `cognitive-core.conf` at the project root using the template format from the cognitive-core framework. Include all sections with comments.

After writing the config, also generate a minimal `CLAUDE.md` at the project root if one does not exist, containing:
- Project name and description
- Quick reference table (language, test command, lint command, main branch)
- Architecture section
- Key rules section

## Language Pack Recommendation

After setup, check if there is a matching language pack plugin available:
- react → `cognitive-core-react`
- angular → `cognitive-core-angular`
- spring-boot → `cognitive-core-spring-boot`
- python → `cognitive-core-python`
- perl → `cognitive-core-perl`

If a language pack exists, suggest:
> "A language pack is available for your stack. Install it with: `claude plugin install cognitive-core-<language>@mindcockpit-tools`"

Note: Language pack plugins are coming soon (Phase 3). For now, suggest using the legacy `install.sh` for language-specific features.
