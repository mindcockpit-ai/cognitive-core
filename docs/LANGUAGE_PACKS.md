# Language Packs Guide

Language packs extend cognitive-core with language-specific configuration, skills, lint rules, and fitness checks. This guide covers the pack structure, how packs are loaded, and how to create your own.

## Available Packs

| Language | Pack Directory | Status | Skills |
|----------|---------------|--------|--------|
| Perl | `language-packs/perl/` | Active | perl-patterns |
| Python | `language-packs/python/` | Active | python-patterns |
| Node.js | `language-packs/node/` | Active | node-messaging |
| Java | `language-packs/java/` | Active | java-messaging |
| Go | `language-packs/go/` | Active | go-messaging |
| Rust | `language-packs/rust/` | Active | rust-messaging |
| C# | `language-packs/csharp/` | Active | csharp-messaging |

Database packs follow the same structure under `database-packs/`:

| Database | Pack Directory | Status | Skills |
|----------|---------------|--------|--------|
| Oracle | `database-packs/oracle/` | Active | oracle-patterns |
| PostgreSQL | `database-packs/postgresql/` | Partial | pack.conf only (skills planned) |
| MySQL | `database-packs/mysql/` | Partial | pack.conf only (skills planned) |

## Pack Structure

```
language-packs/<language>/
+-- pack.conf                    # CC_* variable defaults for this language
+-- skills/
|   +-- <language>-patterns/
|       +-- SKILL.md             # Language-specific patterns and rules
|       +-- references/          # Detailed reference material (optional)
+-- scripts/
|   +-- fitness-check.sh         # Language-specific fitness checks (optional)
+-- compact-rules.md             # Rules re-injected after compaction (optional)
+-- monitor-patterns.conf        # Language-specific error patterns for workspace-monitor (optional)
+-- lint-config/                 # Lint tool configuration files (optional)
```

### pack.conf

The `pack.conf` file defines language-specific defaults using the same `CC_*` variable format as `cognitive-core.conf`. Example from the Python pack:

```bash
CC_LANGUAGE="python"
CC_LINT_COMMAND="ruff check \$1"
CC_LINT_EXTENSIONS=".py"
CC_TEST_COMMAND="pytest tests/"
CC_FORMAT_COMMAND="ruff format --check \$1"
CC_TEST_PATTERN="tests/**/*.py"
CC_ENV_VARS="PYTHONPATH=\${PROJECT_DIR}/src:\$PYTHONPATH"
CC_BLOCKED_PATTERNS=""
```

These values are used as defaults during interactive installation when the user selects this language. They can be overridden in the project's `cognitive-core.conf`.

### skills/ Directory

Each pack can include one or more skills. Skills are directories containing a `SKILL.md` file with patterns, rules, and guidance specific to the language.

During installation, pack skills are copied to `.claude/skills/<skill-name>/` alongside the core skills.

### scripts/fitness-check.sh

Optional. If present and executable, the fitness check system calls this script during quality scoring. The script must output a score (0-100) and a description on the first line:

```
85 All lint checks passed with severity 4
```

The remaining 40% weight in the fitness score is allocated to pack checks.

### compact-rules.md

Optional. If present, the compact-reminder hook loads and injects these rules after context compaction. This ensures language-specific critical rules survive compaction.

## How install.sh Loads Packs

When `CC_LANGUAGE` is set to a value other than `"none"`, the installer:

1. Checks if `language-packs/<CC_LANGUAGE>/` exists
2. Copies all skills from `language-packs/<CC_LANGUAGE>/skills/` to `.claude/skills/`
3. Copies any additional files (non-directory items) from the pack root to `.claude/`

The same process applies to `CC_DATABASE` and `database-packs/`.

```bash
# Relevant section from install.sh
LANG_DIR="${SCRIPT_DIR}/language-packs/${CC_LANGUAGE}"
if [ -d "$LANG_DIR" ]; then
    # Copy language-specific skills
    if [ -d "${LANG_DIR}/skills" ]; then
        for skill_dir in "${LANG_DIR}/skills/"*/; do
            skill_name=$(basename "$skill_dir")
            mkdir -p "${CLAUDE_DIR}/skills/${skill_name}"
            cp -R "${skill_dir}"* "${CLAUDE_DIR}/skills/${skill_name}/"
        done
    fi
fi
```

## Creating a New Language Pack

### Step 1: Create the Directory Structure

```bash
mkdir -p language-packs/ruby/skills/ruby-patterns/references
mkdir -p language-packs/ruby/scripts
```

### Step 2: Write pack.conf

```bash
# language-packs/ruby/pack.conf

CC_LANGUAGE="ruby"
CC_LINT_COMMAND="rubocop \$1"
CC_LINT_EXTENSIONS=".rb .rake"
CC_TEST_COMMAND="bundle exec rspec"
CC_FORMAT_COMMAND=""
CC_TEST_PATTERN="spec/**/*_spec.rb"
CC_ENV_VARS=""
CC_BLOCKED_PATTERNS=""
```

### Step 3: Create the Patterns Skill

Write `language-packs/ruby/skills/ruby-patterns/SKILL.md`:

```markdown
---
name: ruby-patterns
description: Ruby and Rails development patterns
user-invocable: false
---

# Ruby Patterns

## Code Standards

- Use frozen_string_literal comment in all files
- Prefer `each` over `for`
- Use guard clauses for early returns
...
```

Keep the SKILL.md concise (under 500 lines). Put detailed examples in `references/`.

### Step 4: Add Fitness Checks (Optional)

Write `language-packs/ruby/scripts/fitness-check.sh`. The script must output a score (0-100) and description on its first line (e.g., `85 All Rubocop checks passed`). Make it executable with `chmod +x`.

### Step 5: Add Compact Rules (Optional)

Write `language-packs/ruby/compact-rules.md` with critical rules that must survive context compaction.

### Step 6: Register in install.sh

Add the language to the `case` statement in `install.sh`:

```bash
ruby) CC_LINT_EXTENSIONS=".rb .rake"; CC_LINT_COMMAND='rubocop $1'; CC_TEST_COMMAND="bundle exec rspec"; CC_TEST_PATTERN="spec/**/*_spec.rb" ;;
```

### Step 7: Test

```bash
# Test installation with the new pack
CC_LANGUAGE=ruby ./install.sh /tmp/test-ruby-project --force

# Verify pack files were copied
ls /tmp/test-ruby-project/.claude/skills/ruby-patterns/

# Test fitness check if created
bash language-packs/ruby/scripts/fitness-check.sh --verbose
```

## Creating a Database Pack

Database packs follow the same structure under `database-packs/`. The `CC_BLOCKED_PATTERNS` variable should append to existing patterns (not replace) so both language and database safety rules are active:

```bash
CC_BLOCKED_PATTERNS="${CC_BLOCKED_PATTERNS:-} db\.drop"
```

## Pack Interaction with Hooks

- **post-edit-lint.sh**: Uses `CC_LINT_COMMAND` and `CC_LINT_EXTENSIONS` from the pack to auto-lint edited files
- **compact-reminder.sh**: Loads and combines `CC_COMPACT_RULES` (project), language `compact-rules.md`, and database `compact-rules.md`
- **setup-env.sh**: Sets `CC_ENV_VARS` from the pack (e.g., `PYTHONPATH`, `PERL5LIB`) on session start

## Contributing

To add a new language or database pack to the framework:

1. Follow the steps above to create the pack
2. Test with `install.sh` and `update.sh`
3. Update `README.md` to list the new pack in the language/database tables
4. Submit a pull request with the conventional commit format: `feat(lang-packs): add Ruby language pack`
