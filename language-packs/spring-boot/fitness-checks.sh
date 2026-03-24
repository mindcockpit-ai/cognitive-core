#!/bin/bash
# cognitive-core language pack: Spring Boot fitness checks
# Called by the fitness-check framework. Outputs: SCORE DESCRIPTION
# Checks Spring Boot-specific quality patterns and anti-patterns.
# Note: set -e omitted intentionally — grep exits non-zero on no-match, which would abort the script
set -u

# Source shared utilities for _cc_rg (ripgrep with grep fallback)
_CC_COMMON="$(cd "$(dirname "$0")/.." && pwd)/_common.sh"
# shellcheck disable=SC1090
[ -f "$_CC_COMMON" ] && source "$_CC_COMMON"

PROJECT_DIR="${1:-.}"
SRC_DIR="$PROJECT_DIR/src/main/java"
[ ! -d "$SRC_DIR" ] && SRC_DIR="$PROJECT_DIR/src"
[ ! -d "$SRC_DIR" ] && SRC_DIR="$PROJECT_DIR"

TEST_DIR="$PROJECT_DIR/src/test/java"
[ ! -d "$TEST_DIR" ] && TEST_DIR="$PROJECT_DIR/src/test"
[ ! -d "$TEST_DIR" ] && TEST_DIR="$PROJECT_DIR/test"

TOTAL_CHECKS=0
PASSED_CHECKS=0
DETAILS=""

add_check() {
    local name="$1" passed="$2" detail="${3:-}"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ "$passed" -eq 1 ]; then
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
    else
        DETAILS="${DETAILS}FAIL: ${name}${detail:+ ($detail)}; "
    fi
}

# === TYPE SAFETY CHECKS ===

# --- Check 1: No raw type usage (List, Map, Set without generics) ---
RAW_TYPES=$(_cc_rg -n '[[:space:]]List[[:space:]].*=[[:space:]]*new\|[[:space:]]Map[[:space:]].*=[[:space:]]*new\|[[:space:]]Set[[:space:]].*=[[:space:]]*new' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -v '/test/' | wc -l | tr -d ' ')
add_check "No raw types" "$( [ "$RAW_TYPES" -le 2 ] && echo 1 || echo 0 )" "${RAW_TYPES} raw type usages"

# --- Check 2: No Object as parameter or return type (weak typing) ---
OBJECT_TYPES=$(_cc_rg -n 'Object>[[:space:]].*(' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -v '/test/' | grep -v '/generated/' | grep -vc '@Override' || true)
add_check "No Object return/param types" "$( [ "$OBJECT_TYPES" -le 3 ] && echo 1 || echo 0 )" "${OBJECT_TYPES} Object usages"

# --- Check 3: No @SuppressWarnings("unchecked") ---
SUPPRESS_UNCHECKED=$(_cc_rg -n '@SuppressWarnings.*unchecked' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -vc '/test/' || true)
add_check "No @SuppressWarnings(unchecked)" "$( [ "$SUPPRESS_UNCHECKED" -eq 0 ] && echo 1 || echo 0 )" "${SUPPRESS_UNCHECKED} suppressions"

# === SPRING PATTERN CHECKS ===

# --- Check 4: Constructor injection over @Autowired field injection ---
FIELD_AUTOWIRED=$(_cc_rg -n '@Autowired' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -v '/test/' | grep -vc 'constructor' || true)
add_check "Constructor injection (no field @Autowired)" "$( [ "$FIELD_AUTOWIRED" -le 2 ] && echo 1 || echo 0 )" "${FIELD_AUTOWIRED} field @Autowired"

# --- Check 5: @ConfigurationProperties over @Value for structured config ---
VALUE_COUNT=$(_cc_rg -n '@Value(' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -vc '/test/' || true)
add_check "@ConfigurationProperties over @Value" "$( [ "$VALUE_COUNT" -le 5 ] && echo 1 || echo 0 )" "${VALUE_COUNT} @Value usages"

# --- Check 6: @Transactional on service layer, not controllers ---
TXN_CONTROLLER=$(_cc_rg -l '@Transactional' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -ciE 'Controller' || true)
add_check "@Transactional not on controllers" "$( [ "$TXN_CONTROLLER" -eq 0 ] && echo 1 || echo 0 )" "${TXN_CONTROLLER} controllers with @Transactional"

# --- Check 7: No WebSecurityConfigurerAdapter (removed in Spring Security 6) ---
LEGACY_SECURITY=$(_cc_rg -n 'WebSecurityConfigurerAdapter' "$SRC_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
add_check "No WebSecurityConfigurerAdapter" "$( [ "$LEGACY_SECURITY" -eq 0 ] && echo 1 || echo 0 )" "${LEGACY_SECURITY} legacy security config"

# === SECURITY CHECKS ===

# --- Check 8: No hardcoded credentials ---
HARDCODED_CREDS=$(_cc_rg -n 'password[[:space:]]*=[[:space:]]*"[^"]*"\|secret[[:space:]]*=[[:space:]]*"[^"]*"\|api[_-]*key[[:space:]]*=[[:space:]]*"[^"]*"' "$SRC_DIR" --include="*.java" --include="*.properties" --include="*.yml" --include="*.yaml" 2>/dev/null | grep -vic 'test\|example\|placeholder\|changeme\|TODO' || true)
add_check "No hardcoded credentials" "$( [ "$HARDCODED_CREDS" -eq 0 ] && echo 1 || echo 0 )" "${HARDCODED_CREDS} hardcoded credentials"

# --- Check 9: CSRF configuration present (not blindly disabled) ---
CSRF_DISABLED=$(_cc_rg -n 'csrf.*disable\|csrf().disable' "$SRC_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
add_check "CSRF not blindly disabled" "$( [ "$CSRF_DISABLED" -eq 0 ] && echo 1 || echo 0 )" "${CSRF_DISABLED} csrf().disable() calls"

# --- Check 10: Actuator endpoints not fully exposed ---
ACTUATOR_EXPOSE_ALL=$(_cc_rg -n 'management.endpoints.web.exposure.include[[:space:]]*=[[:space:]]*[*]' "$PROJECT_DIR" --include="*.properties" --include="*.yml" --include="*.yaml" 2>/dev/null | wc -l | tr -d ' ')
add_check "Actuator not fully exposed" "$( [ "$ACTUATOR_EXPOSE_ALL" -eq 0 ] && echo 1 || echo 0 )" "${ACTUATOR_EXPOSE_ALL} expose-all configs"

# === TESTING CHECKS ===

# --- Check 11: Test files exist (reasonable ratio) ---
TEST_COUNT=0
SOURCE_COUNT=0
if [ -d "$TEST_DIR" ]; then
    TEST_COUNT=$(find "$TEST_DIR" -type f -name "*Test.java" -o -name "*Tests.java" -o -name "*IT.java" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ -d "$SRC_DIR" ]; then
    SOURCE_COUNT=$(find "$SRC_DIR" -type f -name "*.java" ! -path "*/test/*" ! -path "*/generated/*" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$SOURCE_COUNT" -gt 0 ]; then
    TEST_RATIO=$(( (TEST_COUNT * 100) / SOURCE_COUNT ))
else
    TEST_RATIO=100
fi
add_check "Test coverage >40% files" "$( [ "$TEST_RATIO" -ge 40 ] && echo 1 || echo 0 )" "${TEST_COUNT} tests / ${SOURCE_COUNT} sources (${TEST_RATIO}%)"

# --- Check 12: @SpringBootTest not overused (prefer test slices) ---
FULL_BOOT_TEST=$(_cc_rg -n '@SpringBootTest' "$TEST_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
SLICE_TEST=$(_cc_rg -n '@WebMvcTest\|@DataJpaTest\|@WebFluxTest\|@JsonTest\|@RestClientTest\|@JdbcTest' "$TEST_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
TOTAL_TEST_CONFIGS=$((FULL_BOOT_TEST + SLICE_TEST))
if [ "$TOTAL_TEST_CONFIGS" -gt 0 ]; then
    SLICE_PERCENT=$(( (SLICE_TEST * 100) / TOTAL_TEST_CONFIGS ))
else
    SLICE_PERCENT=100
fi
add_check "Test slices over @SpringBootTest >40%" "$( [ "$SLICE_PERCENT" -ge 40 ] || [ "$TOTAL_TEST_CONFIGS" -le 2 ] && echo 1 || echo 0 )" "${SLICE_PERCENT}% slices (${SLICE_TEST} slice / ${FULL_BOOT_TEST} full)"

# --- Check 13: Testcontainers usage (integration tests) ---
TESTCONTAINERS=$(_cc_rg -n 'Testcontainers\|@Container\|@ServiceConnection' "$TEST_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
IT_FILES=$(find "$TEST_DIR" -type f -name "*IT.java" 2>/dev/null | wc -l | tr -d ' ')
if [ "$IT_FILES" -gt 0 ]; then
    add_check "Testcontainers for integration tests" "$( [ "$TESTCONTAINERS" -gt 0 ] && echo 1 || echo 0 )" "${TESTCONTAINERS} Testcontainers refs, ${IT_FILES} IT files"
else
    add_check "Testcontainers for integration tests" 1 "no IT files (ok for unit-only)"
fi

# === VERSION-SPECIFIC CHECKS ===

# --- Check 14: javax vs jakarta imports (v3+ must use jakarta) ---
BOOT_VERSION=""
if [ -f "$PROJECT_DIR/pom.xml" ]; then
    BOOT_VERSION=$(grep -A2 'spring-boot-starter-parent' "$PROJECT_DIR/pom.xml" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
fi
if [ -z "$BOOT_VERSION" ] && [ -f "$PROJECT_DIR/build.gradle" ]; then
    BOOT_VERSION=$(grep 'org.springframework.boot' "$PROJECT_DIR/build.gradle" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
fi
if [ -z "$BOOT_VERSION" ] && [ -f "$PROJECT_DIR/build.gradle.kts" ]; then
    BOOT_VERSION=$(grep 'org.springframework.boot' "$PROJECT_DIR/build.gradle.kts" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
fi
BOOT_VERSION=${BOOT_VERSION:-0}

JAVAX_IMPORTS=$(_cc_rg -n 'import javax\.' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -v '/test/' | grep -vc 'javax.crypto\|javax.net\|javax.sql' || true)
if [ "$BOOT_VERSION" -ge 3 ]; then
    add_check "jakarta imports (no javax for v3+)" "$( [ "$JAVAX_IMPORTS" -eq 0 ] && echo 1 || echo 0 )" "${JAVAX_IMPORTS} javax imports in v${BOOT_VERSION}"
else
    add_check "javax/jakarta imports" 1 "v${BOOT_VERSION} uses javax (correct)"
fi

# --- Check 15: RestTemplate vs RestClient (v3.2+ should use RestClient) ---
REST_TEMPLATE=$(_cc_rg -n 'RestTemplate' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -vc '/test/' || true)
REST_CLIENT=$(_cc_rg -n 'RestClient' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -vc '/test/' || true)
if [ "$BOOT_VERSION" -ge 3 ]; then
    add_check "RestClient over RestTemplate (v3.2+)" "$( [ "$REST_TEMPLATE" -le 2 ] || [ "$REST_CLIENT" -gt 0 ] && echo 1 || echo 0 )" "${REST_TEMPLATE} RestTemplate, ${REST_CLIENT} RestClient"
else
    add_check "HTTP client usage" 1 "v${BOOT_VERSION} uses RestTemplate (correct)"
fi

# --- Check 16: Virtual threads configuration (v3.2+ / Java 21+) ---
if [ "$BOOT_VERSION" -ge 3 ]; then
    VIRTUAL_THREADS=$(_cc_rg -n 'virtual-threads\|virtual.threads' "$PROJECT_DIR" --include="*.properties" --include="*.yml" --include="*.yaml" 2>/dev/null | wc -l | tr -d ' ')
    add_check "Virtual threads considered (v3.2+)" "$( [ "$VIRTUAL_THREADS" -gt 0 ] && echo 1 || echo 0 )" "${VIRTUAL_THREADS} virtual thread configs"
else
    add_check "Virtual threads (v2.x not applicable)" 1 "v${BOOT_VERSION} (virtual threads N/A)"
fi

# === CODE QUALITY CHECKS ===

# --- Check 17: No System.out.println in production code ---
SYSOUT=$(_cc_rg -n 'System\.out\.print\|System\.err\.print' "$SRC_DIR" --include="*.java" 2>/dev/null | grep -vc '/test/' || true)
add_check "No System.out.println" "$( [ "$SYSOUT" -eq 0 ] && echo 1 || echo 0 )" "${SYSOUT} System.out/err usages"

# --- Check 18: Proper exception handling (@RestControllerAdvice) ---
CONTROLLER_ADVICE=$(_cc_rg -n '@RestControllerAdvice\|@ControllerAdvice' "$SRC_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
CONTROLLERS=$(_cc_rg -n '@RestController\|@Controller' "$SRC_DIR" --include="*.java" 2>/dev/null | wc -l | tr -d ' ')
if [ "$CONTROLLERS" -gt 0 ]; then
    add_check "Global exception handling exists" "$( [ "$CONTROLLER_ADVICE" -gt 0 ] && echo 1 || echo 0 )" "${CONTROLLER_ADVICE} @ControllerAdvice (${CONTROLLERS} controllers)"
else
    add_check "Global exception handling" 1 "no controllers (ok)"
fi

# Calculate score
if [ "$TOTAL_CHECKS" -gt 0 ]; then
    SCORE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
else
    SCORE=50
fi

DETAILS="${DETAILS%; }"

echo "$SCORE ${PASSED_CHECKS}/${TOTAL_CHECKS} Spring Boot checks passed${DETAILS:+. $DETAILS}"
