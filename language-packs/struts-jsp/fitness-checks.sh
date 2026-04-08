#!/bin/bash
# cognitive-core language pack: Struts + JSP fitness checks
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Focus: code quality, security, migration readiness assessment
set -u

# Source shared utilities for _cc_rg (ripgrep with grep fallback)
_CC_COMMON="$(cd "$(dirname "$0")/.." && pwd)/_common.sh"
# shellcheck disable=SC1090
[ -f "$_CC_COMMON" ] && source "$_CC_COMMON"

PROJECT_DIR="${1:-.}"
_cc_fitness_init
add_check() { _cc_fitness_check "$@"; }

# ---- Detect project structure ----
# Find Java source root
SRC_DIR=""
for candidate in "$PROJECT_DIR/src/main/java" "$PROJECT_DIR/src" "$PROJECT_DIR/java"; do
    if [ -d "$candidate" ]; then
        SRC_DIR="$candidate"
        break
    fi
done

WEB_DIR=""
for candidate in "$PROJECT_DIR/src/main/webapp" "$PROJECT_DIR/WebContent" "$PROJECT_DIR/web" "$PROJECT_DIR/webapp"; do
    if [ -d "$candidate" ]; then
        WEB_DIR="$candidate"
        break
    fi
done

# ---- Type Safety Checks ----

# Check for raw types (Map, List without generics)
if [ -n "$SRC_DIR" ] && [ -d "$SRC_DIR" ]; then
    raw_types=$(_cc_rg -n 'Map[[:space:]]*[a-z]' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -v 'Map<' | grep -cv '^\s*//' || echo "0")
    add_check "No raw Map types" "$([ "$raw_types" -lt 5 ] && echo 1 || echo 0)" "${raw_types} raw Map usages"

    # Check for Object parameters
    obj_params=$(_cc_rg -n 'Object[[:space:]]\+[a-z]' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -cv '^\s*//' || echo "0")
    add_check "Minimal Object params" "$([ "$obj_params" -lt 10 ] && echo 1 || echo 0)" "${obj_params} Object params"

    # Check for @SuppressWarnings abuse
    suppress_count=$(_cc_rg -c '@SuppressWarnings' "$SRC_DIR" --include="*.java" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
    add_check "Minimal @SuppressWarnings" "$([ "$suppress_count" -lt 20 ] && echo 1 || echo 0)" "${suppress_count} suppressions"
fi

# ---- JSP Quality Checks ----

if [ -n "$WEB_DIR" ] && [ -d "$WEB_DIR" ]; then
    # Count scriptlet usage
    scriptlet_count=$(_cc_rg -c '<%[^@=-]' "$WEB_DIR" --include="*.jsp" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
    add_check "JSP scriptlet audit" "$([ "$scriptlet_count" -lt 50 ] && echo 1 || echo 0)" "${scriptlet_count} scriptlets"

    # Check for JSTL usage (good sign)
    jstl_count=$(_cc_rg -c 'taglib.*jstl\|<c:\|<fmt:' "$WEB_DIR" --include="*.jsp" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
    add_check "JSTL adoption" "$([ "$jstl_count" -gt 0 ] && echo 1 || echo 0)" "${jstl_count} JSTL usages"

    # Check for inline JavaScript in JSPs
    inline_js=$(_cc_rg -c '<script[^>]*>' "$WEB_DIR" --include="*.jsp" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
    add_check "Minimal inline JS in JSP" "$([ "$inline_js" -lt 20 ] && echo 1 || echo 0)" "${inline_js} inline scripts"

    # Check for inline SQL in JSPs (very bad)
    inline_sql=$(_cc_rg -c -i 'SELECT.*FROM\|INSERT.*INTO\|UPDATE.*SET\|DELETE.*FROM' "$WEB_DIR" --include="*.jsp" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
    add_check "No SQL in JSPs" "$([ "$inline_sql" -eq 0 ] && echo 1 || echo 0)" "${inline_sql} SQL statements in JSPs"
fi

# ---- Struts Configuration Checks ----

# Struts 1.x config
STRUTS1_CONFIG=""
for cfg in "$PROJECT_DIR/src/main/webapp/WEB-INF/struts-config.xml" "$PROJECT_DIR/WebContent/WEB-INF/struts-config.xml" "$PROJECT_DIR/web/WEB-INF/struts-config.xml"; do
    if [ -f "$cfg" ]; then
        STRUTS1_CONFIG="$cfg"
        break
    fi
done

# Struts 2.x config
STRUTS2_CONFIG=""
for cfg in "$PROJECT_DIR/src/main/resources/struts.xml" "$PROJECT_DIR/src/struts.xml" "$PROJECT_DIR/resources/struts.xml"; do
    if [ -f "$cfg" ]; then
        STRUTS2_CONFIG="$cfg"
        break
    fi
done

if [ -n "$STRUTS1_CONFIG" ]; then
    # Check for validate=false actions (skips form validation)
    no_validate=$(grep -c 'validate="false"' "$STRUTS1_CONFIG" 2>/dev/null || echo "0")
    add_check "Struts1: validation enabled" "$([ "$no_validate" -lt 5 ] && echo 1 || echo 0)" "${no_validate} unvalidated actions"
fi

if [ -n "$STRUTS2_CONFIG" ]; then
    # Check for devMode (must be false in production)
    dev_mode=$(grep -c 'devMode.*true' "$STRUTS2_CONFIG" 2>/dev/null || echo "0")
    add_check "Struts2: devMode disabled" "$([ "$dev_mode" -eq 0 ] && echo 1 || echo 0)" "devMode is enabled"

    # Check for OGNL in redirects (security risk)
    ognl_redirect=$(grep -c 'redirectAction.*\$' "$STRUTS2_CONFIG" 2>/dev/null || echo "0")
    add_check "Struts2: no OGNL in redirects" "$([ "$ognl_redirect" -eq 0 ] && echo 1 || echo 0)" "${ognl_redirect} OGNL redirects"
fi

# ---- Security Checks ----

if [ -n "$SRC_DIR" ] && [ -d "$SRC_DIR" ]; then
    # Check for SQL injection patterns (string concat in queries)
    sql_concat=$(_cc_rg -n 'createQuery\|createSQLQuery\|prepareStatement\|executeQuery' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -c '+' || echo "0")
    add_check "No SQL string concatenation" "$([ "$sql_concat" -eq 0 ] && echo 1 || echo 0)" "${sql_concat} potential SQL injections"

    # Check for hardcoded credentials
    hardcoded_creds=$(_cc_rg -n -i 'password\s*=\s*"[^"]\+"\|passwd\s*=\s*"' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -cv '^\s*//' || echo "0")
    add_check "No hardcoded credentials" "$([ "$hardcoded_creds" -eq 0 ] && echo 1 || echo 0)" "${hardcoded_creds} hardcoded credentials"

    # Check for System.out (should use logging)
    sysout=$(_cc_rg -c 'System\.out\.\|System\.err\.' "$SRC_DIR" --include="*.java" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
    add_check "No System.out (use logger)" "$([ "$sysout" -lt 10 ] && echo 1 || echo 0)" "${sysout} System.out calls"

    # Check for exception swallowing
    empty_catch=$(_cc_rg -n 'catch.*{' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -c '{}' || echo "0")
    add_check "No empty catch blocks" "$([ "$empty_catch" -eq 0 ] && echo 1 || echo 0)" "${empty_catch} empty catches"
fi

# ---- Testing Checks ----

TEST_DIR=""
for candidate in "$PROJECT_DIR/src/test/java" "$PROJECT_DIR/test" "$PROJECT_DIR/tests"; do
    if [ -d "$candidate" ]; then
        TEST_DIR="$candidate"
        break
    fi
done

if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
    test_count=$(find "$TEST_DIR" -name "*Test.java" -o -name "*Tests.java" -o -name "Test*.java" 2>/dev/null | wc -l | tr -d ' ')
    add_check "Has test files" "$([ "$test_count" -gt 0 ] && echo 1 || echo 0)" "${test_count} test files"

    # Check for assertions (not just test methods)
    assertions=$(_cc_rg -c 'assert\|assertEquals\|assertTrue\|assertThat\|verify(' "$TEST_DIR" --include="*.java" 2>/dev/null | awk -F: '{sum+=$2} END{print sum+0}')
    add_check "Tests have assertions" "$([ "$assertions" -gt 5 ] && echo 1 || echo 0)" "${assertions} assertions"
else
    add_check "Test directory exists" 0 "no test directory found"
fi

# ---- Build System Check ----

has_maven=$([ -f "$PROJECT_DIR/pom.xml" ] && echo 1 || echo 0)
has_gradle=$([ -f "$PROJECT_DIR/build.gradle" ] || [ -f "$PROJECT_DIR/build.gradle.kts" ] && echo 1 || echo 0)
has_ant=$([ -f "$PROJECT_DIR/build.xml" ] && echo 1 || echo 0)
add_check "Has build system" "$([ "$has_maven" -eq 1 ] || [ "$has_gradle" -eq 1 ] || [ "$has_ant" -eq 1 ] && echo 1 || echo 0)" "maven:${has_maven} gradle:${has_gradle} ant:${has_ant}"

# ---- web.xml Check ----

WEB_XML=""
for candidate in "$PROJECT_DIR/src/main/webapp/WEB-INF/web.xml" "$PROJECT_DIR/WebContent/WEB-INF/web.xml" "$PROJECT_DIR/web/WEB-INF/web.xml"; do
    if [ -f "$candidate" ]; then
        WEB_XML="$candidate"
        break
    fi
done

if [ -n "$WEB_XML" ]; then
    add_check "web.xml exists" 1
else
    add_check "web.xml exists" 0 "no web.xml found"
fi

# ---- Output ----
if [ "$_CC_FITNESS_TOTAL" -eq 0 ]; then
    echo "0 No Struts/JSP project structure detected"
    exit 0
fi

_cc_fitness_result "Struts/JSP checks"
