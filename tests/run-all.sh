#!/bin/bash
# cognitive-core test runner
# Runs all test suites in order and reports aggregate results
#
# Usage:
#   bash tests/run-all.sh          # Normal ANSI output
#   bash tests/run-all.sh --json   # Structured JSON output
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

JSON_MODE=false
if [[ "${1:-}" == "--json" ]]; then
    JSON_MODE=true
fi

# ---- ANSI colors (unused in JSON mode) ----
BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

# ---- Pretty names for suites (bash 3.2 compatible) ----
suite_pretty_name() {
    case "$1" in
        01-shellcheck.sh)        echo "ShellCheck" ;;
        02-skill-frontmatter.sh) echo "Skill Frontmatter" ;;
        03-hook-protocol.sh)     echo "Hook Protocol" ;;
        04-install-dryrun.sh)    echo "Install Dry-Run" ;;
        05-update-flow.sh)       echo "Update Flow" ;;
        06-security-hooks.sh)    echo "Security Hooks" ;;
        07-agent-permissions.sh) echo "Agent Permissions" ;;
        08-workspace-monitor.sh) echo "Workspace Monitor" ;;
        *) echo "$1" ;;
    esac
}

# ---- Component counting ----
count_components() {
    local agents=0 skills=0 hooks=0 lang_packs=0 db_packs=0

    # Agents: .md files in core/agents/
    if [ -d "${ROOT_DIR}/core/agents" ]; then
        agents=$(find "${ROOT_DIR}/core/agents" -maxdepth 1 -name "*.md" -type f | wc -l | tr -d ' ')
    fi

    # Skills: subdirectories in core/skills/
    if [ -d "${ROOT_DIR}/core/skills" ]; then
        skills=$(find "${ROOT_DIR}/core/skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    fi

    # Hooks: .sh files in core/hooks/ (exclude _lib.sh)
    if [ -d "${ROOT_DIR}/core/hooks" ]; then
        hooks=$(find "${ROOT_DIR}/core/hooks" -maxdepth 1 -name "*.sh" -not -name "_*" -type f | wc -l | tr -d ' ')
    fi

    # Language packs: subdirectories in language-packs/
    if [ -d "${ROOT_DIR}/language-packs" ]; then
        lang_packs=$(find "${ROOT_DIR}/language-packs" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    fi

    # Database packs: subdirectories in database-packs/
    if [ -d "${ROOT_DIR}/database-packs" ]; then
        db_packs=$(find "${ROOT_DIR}/database-packs" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
    fi

    printf '{"agents":%d,"skills":%d,"hooks":%d,"language_packs":%d,"database_packs":%d}' \
        "$agents" "$skills" "$hooks" "$lang_packs" "$db_packs"
}

# ---- Featured component extraction ----
# Reads YAML frontmatter from agent/skill .md files and extracts featured items
collect_featured() {
    local type="$1" dir="$2" filename="$3"
    local json=""

    if [ ! -d "$dir" ]; then
        echo "[]"
        return
    fi

    while IFS= read -r file; do
        [ -f "$file" ] || continue

        # Check if featured: true exists in frontmatter
        local in_frontmatter=false has_featured=false
        local item_name="" item_desc=""

        while IFS= read -r line; do
            if [ "$line" = "---" ]; then
                if [ "$in_frontmatter" = true ]; then
                    break
                fi
                in_frontmatter=true
                continue
            fi
            if [ "$in_frontmatter" = true ]; then
                case "$line" in
                    name:*)            item_name=$(echo "$line" | sed 's/^name: *//') ;;
                    featured:*true*)   has_featured=true ;;
                    featured_description:*) item_desc=$(echo "$line" | sed 's/^featured_description: *//') ;;
                esac
            fi
        done < "$file"

        if [ "$has_featured" = true ] && [ -n "$item_name" ]; then
            # Escape quotes in description
            item_desc=$(printf '%s' "$item_desc" | sed 's/"/\\"/g')
            local entry
            entry=$(printf '{"type":"%s","name":"%s","description":"%s"}' "$type" "$item_name" "$item_desc")
            if [ -n "$json" ]; then
                json="${json},${entry}"
            else
                json="${entry}"
            fi
        fi
    done < <(find "$dir" -name "$filename" -type f | sort)

    echo "[${json}]"
}

# ---- Full catalog extraction ----
# Reads ALL agents/skills (not just featured) with descriptions for the website catalog
collect_catalog() {
    local type="$1" dir="$2" filename="$3"
    local json=""

    if [ ! -d "$dir" ]; then
        echo "[]"
        return
    fi

    while IFS= read -r file; do
        [ -f "$file" ] || continue

        local in_frontmatter=false
        local item_name="" item_desc="" catalog_desc="" featured_desc=""
        local is_featured=false

        while IFS= read -r line; do
            if [ "$line" = "---" ]; then
                if [ "$in_frontmatter" = true ]; then
                    break
                fi
                in_frontmatter=true
                continue
            fi
            if [ "$in_frontmatter" = true ]; then
                case "$line" in
                    name:*)                 item_name=$(echo "$line" | sed 's/^name: *//') ;;
                    featured:*true*)        is_featured=true ;;
                    featured_description:*) featured_desc=$(echo "$line" | sed 's/^featured_description: *//') ;;
                    catalog_description:*)  catalog_desc=$(echo "$line" | sed 's/^catalog_description: *//') ;;
                    description:*)          item_desc=$(echo "$line" | sed 's/^description: *//') ;;
                esac
            fi
        done < "$file"

        if [ -n "$item_name" ]; then
            # Priority: catalog_description > featured_description > description (truncated)
            local desc="$catalog_desc"
            if [ -z "$desc" ]; then
                desc="$featured_desc"
            fi
            if [ -z "$desc" ]; then
                desc=$(printf '%.120s' "$item_desc")
            fi
            # Escape quotes in description
            desc=$(printf '%s' "$desc" | sed 's/"/\\"/g')
            local featured_val="false"
            if [ "$is_featured" = true ]; then
                featured_val="true"
            fi
            local entry
            entry=$(printf '{"type":"%s","name":"%s","description":"%s","featured":%s}' "$type" "$item_name" "$desc" "$featured_val")
            if [ -n "$json" ]; then
                json="${json},${entry}"
            else
                json="${entry}"
            fi
        fi
    done < <(find "$dir" -name "$filename" -type f | sort)

    echo "[${json}]"
}

# ---- Normal (ANSI) mode ----
if [ "$JSON_MODE" = false ]; then
    printf "\n${BOLD}${CYAN}╔══════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}${CYAN}║   cognitive-core test suite runner    ║${RESET}\n"
    printf "${BOLD}${CYAN}╚══════════════════════════════════════╝${RESET}\n"

    TOTAL_PASS=0
    TOTAL_FAIL=0
    FAILED_SUITES=""

    for suite in "${SCRIPT_DIR}/suites/"*.sh; do
        if [ ! -f "$suite" ]; then
            continue
        fi
        suite_name=$(basename "$suite")

        if bash "$suite"; then
            TOTAL_PASS=$((TOTAL_PASS + 1))
        else
            TOTAL_FAIL=$((TOTAL_FAIL + 1))
            FAILED_SUITES="${FAILED_SUITES} ${suite_name}"
        fi
    done

    TOTAL=$((TOTAL_PASS + TOTAL_FAIL))
    printf "\n${BOLD}${CYAN}═══════════════════════════════════════${RESET}\n"
    printf "${BOLD}Aggregate: %d/%d suites passed${RESET}\n" "$TOTAL_PASS" "$TOTAL"

    if [ "$TOTAL_FAIL" -gt 0 ]; then
        printf "${RED}Failed suites:${RESET}%s\n" "$FAILED_SUITES"
        exit 1
    else
        printf "${GREEN}All suites passed.${RESET}\n"
        exit 0
    fi
fi

# ---- JSON mode ----
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
COMMIT=$(cd "${ROOT_DIR}" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
VERSION=$(cat "${ROOT_DIR}/VERSION" 2>/dev/null || echo "0.0.0")

SUITES_TOTAL=0
SUITES_PASSED=0
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
SUITES_JSON=""

for suite in "${SCRIPT_DIR}/suites/"*.sh; do
    if [ ! -f "$suite" ]; then
        continue
    fi
    suite_file=$(basename "$suite")
    suite_label=$(suite_pretty_name "$suite_file")

    SUITES_TOTAL=$((SUITES_TOTAL + 1))

    # Capture output and exit code
    suite_exit=0
    suite_output=$(bash "$suite" 2>&1) || suite_exit=$?

    # Parse the Results line: "Results: X passed, Y failed, Z skipped (of N)"
    results_line=$(echo "$suite_output" | grep -oE '[0-9]+ passed, [0-9]+ failed, [0-9]+ skipped' || echo "0 passed, 0 failed, 0 skipped")

    s_passed=$(echo "$results_line" | grep -oE '^[0-9]+')
    s_failed=$(echo "$results_line" | sed 's/.*passed, //' | grep -oE '^[0-9]+')
    s_skipped=$(echo "$results_line" | sed 's/.*failed, //' | grep -oE '^[0-9]+')
    s_total=$((s_passed + s_failed + s_skipped))

    TESTS_PASSED=$((TESTS_PASSED + s_passed))
    TESTS_FAILED=$((TESTS_FAILED + s_failed))
    TESTS_SKIPPED=$((TESTS_SKIPPED + s_skipped))
    TESTS_TOTAL=$((TESTS_TOTAL + s_total))

    if [ "$suite_exit" -eq 0 ]; then
        SUITES_PASSED=$((SUITES_PASSED + 1))
    fi

    # Build suite JSON entry
    entry=$(printf '{"name":"%s","passed":%d,"failed":%d,"skipped":%d,"total":%d}' \
        "$suite_label" "$s_passed" "$s_failed" "$s_skipped" "$s_total")

    if [ -n "$SUITES_JSON" ]; then
        SUITES_JSON="${SUITES_JSON},${entry}"
    else
        SUITES_JSON="${entry}"
    fi
done

ALL_PASSED=false
if [ "$TESTS_FAILED" -eq 0 ]; then
    ALL_PASSED=true
fi

COMPONENTS=$(count_components)

# Collect featured agents and skills
FEATURED_AGENTS=$(collect_featured "agent" "${ROOT_DIR}/core/agents" "*.md")
FEATURED_SKILLS=$(collect_featured "skill" "${ROOT_DIR}/core/skills" "SKILL.md")

# Collect full catalog (all agents + skills with descriptions)
CATALOG_AGENTS=$(collect_catalog "agent" "${ROOT_DIR}/core/agents" "*.md")
CATALOG_SKILLS=$(collect_catalog "skill" "${ROOT_DIR}/core/skills" "SKILL.md")

# Merge featured lists
if [ "$FEATURED_AGENTS" = "[]" ] && [ "$FEATURED_SKILLS" = "[]" ]; then
    FEATURED="[]"
elif [ "$FEATURED_AGENTS" = "[]" ]; then
    FEATURED="$FEATURED_SKILLS"
elif [ "$FEATURED_SKILLS" = "[]" ]; then
    FEATURED="$FEATURED_AGENTS"
else
    # Strip brackets and merge
    fa_inner=$(echo "$FEATURED_AGENTS" | sed 's/^\[//;s/\]$//')
    fs_inner=$(echo "$FEATURED_SKILLS" | sed 's/^\[//;s/\]$//')
    FEATURED="[${fa_inner},${fs_inner}]"
fi

# Merge catalog lists
if [ "$CATALOG_AGENTS" = "[]" ] && [ "$CATALOG_SKILLS" = "[]" ]; then
    CATALOG="[]"
elif [ "$CATALOG_AGENTS" = "[]" ]; then
    CATALOG="$CATALOG_SKILLS"
elif [ "$CATALOG_SKILLS" = "[]" ]; then
    CATALOG="$CATALOG_AGENTS"
else
    ca_inner=$(echo "$CATALOG_AGENTS" | sed 's/^\[//;s/\]$//')
    cs_inner=$(echo "$CATALOG_SKILLS" | sed 's/^\[//;s/\]$//')
    CATALOG="[${ca_inner},${cs_inner}]"
fi

# Output final JSON
printf '{
  "timestamp": "%s",
  "commit": "%s",
  "version": "%s",
  "suites_total": %d,
  "suites_passed": %d,
  "tests_total": %d,
  "tests_passed": %d,
  "tests_failed": %d,
  "tests_skipped": %d,
  "all_passed": %s,
  "suites": [%s],
  "components": %s,
  "featured": %s,
  "catalog": %s
}\n' \
    "$TIMESTAMP" "$COMMIT" "$VERSION" \
    "$SUITES_TOTAL" "$SUITES_PASSED" \
    "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED" "$TESTS_SKIPPED" \
    "$ALL_PASSED" "$SUITES_JSON" "$COMPONENTS" "$FEATURED" "$CATALOG"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0
