#!/bin/bash
# cognitive-core hook: PreToolUse (Write, Edit)
# Spring Boot version-aware pattern enforcement
# Detects Spring Boot version from pom.xml or build.gradle and warns about deprecated patterns
# Uses "ask" (not "deny") — graduated response per framework philosophy
# All patterns use POSIX ERE (no \s, \b, \w) for macOS + Linux compatibility
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Only activate for Spring Boot projects
[ "${CC_LANGUAGE:-}" = "spring-boot" ] || exit 0

# Read stdin JSON
INPUT=$(cat)

# Extract tool name and content being written
TOOL_NAME=$(echo "$INPUT" | _cc_json_get ".tool_name")
CONTENT=""

case "$TOOL_NAME" in
    Write)
        CONTENT=$(echo "$INPUT" | _cc_json_get ".tool_input.content")
        FILE_PATH=$(echo "$INPUT" | _cc_json_get ".tool_input.file_path")
        ;;
    Edit)
        CONTENT=$(echo "$INPUT" | _cc_json_get ".tool_input.new_string")
        FILE_PATH=$(echo "$INPUT" | _cc_json_get ".tool_input.file_path")
        ;;
    *)
        exit 0
        ;;
esac

# Only check Java, Kotlin, XML, and config files
_IS_CONFIG="false"
case "$FILE_PATH" in
    *.java|*.kt|*.xml) ;;
    *.yml|*.yaml|*.properties) _IS_CONFIG="true" ;;
    *) exit 0 ;;
esac

# Detect test files — skip security patterns but allow migration checks (#172)
_IS_TEST="false"
case "$FILE_PATH" in
    *Test.java|*Tests.java|*IT.java) _IS_TEST="true" ;;
esac
case "$FILE_PATH" in
    */test/*|*/tests/*) _IS_TEST="true" ;;
esac

[ -z "$CONTENT" ] && exit 0

# --- Detect Spring Boot version (project-local cache with mtime invalidation, #176) ---
SB_VERSION=$(_cc_version_cache_get "spring-boot" "pom.xml build.gradle build.gradle.kts")

if [ -z "$SB_VERSION" ]; then
    SB_VERSION=0
    if [ -f "${CC_PROJECT_DIR}/pom.xml" ]; then
        SB_VERSION=$(grep -A2 'spring-boot-starter-parent' "${CC_PROJECT_DIR}/pom.xml" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
    fi
    if [ -z "$SB_VERSION" ] || [ "$SB_VERSION" = "0" ]; then
        if [ -f "${CC_PROJECT_DIR}/build.gradle" ]; then
            SB_VERSION=$(grep 'org.springframework.boot' "${CC_PROJECT_DIR}/build.gradle" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
        fi
    fi
    if [ -z "$SB_VERSION" ] || [ "$SB_VERSION" = "0" ]; then
        if [ -f "${CC_PROJECT_DIR}/build.gradle.kts" ]; then
            SB_VERSION=$(grep 'org.springframework.boot' "${CC_PROJECT_DIR}/build.gradle.kts" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
        fi
    fi
    SB_VERSION=${SB_VERSION:-0}
    _cc_version_cache_set "spring-boot" "$SB_VERSION"
fi

[ "$SB_VERSION" -eq 0 ] && exit 0

DENY_REASONS=()
ASK_REASONS=()

# --- v3+ patterns (javax to jakarta, Security 6) — DENY: removed APIs ---
if [ "$SB_VERSION" -ge 3 ]; then
    if echo "$CONTENT" | grep -qE 'import[[:space:]]+javax\.(persistence|validation|servlet|annotation|mail|transaction|inject|enterprise)'; then
        DENY_REASONS+=("Use jakarta.* imports instead of javax.* — required since Spring Boot 3.0.")
    fi
    if echo "$CONTENT" | grep -qE 'WebSecurityConfigurerAdapter'; then
        DENY_REASONS+=("WebSecurityConfigurerAdapter removed in Security 6. Use @Bean SecurityFilterChain.")
    fi
    if echo "$CONTENT" | grep -qE '\.antMatchers[[:space:]]*\('; then
        DENY_REASONS+=("antMatchers() removed in Security 6. Use requestMatchers().")
    fi
    if echo "$CONTENT" | grep -qE '\.authorizeRequests[[:space:]]*\('; then
        ASK_REASONS+=("authorizeRequests() is deprecated. Use authorizeHttpRequests() with lambda DSL.")
    fi
fi

# --- v3.2+ patterns (RestClient, virtual threads) — ASK: deprecated ---
if [ "$SB_VERSION" -ge 3 ]; then
    if echo "$CONTENT" | grep -qE 'new[[:space:]]+RestTemplate[[:space:]]*\(|RestTemplate[[:space:]]+restTemplate'; then
        ASK_REASONS+=("Consider RestClient instead of RestTemplate (maintenance mode since v3.2).")
    fi
    if [ "$_IS_TEST" = "false" ] && echo "$CONTENT" | grep -qE 'Thread[[:space:]]*\.[[:space:]]*sleep[[:space:]]*\('; then
        ASK_REASONS+=("Avoid Thread.sleep() in production. Use @Scheduled, CompletableFuture, or virtual threads.")
    fi
fi

# --- v4+ patterns (Java 21, Security 7, Jackson 3) ---
if [ "$SB_VERSION" -ge 4 ]; then
    if [ "$_IS_TEST" = "false" ] && echo "$CONTENT" | grep -qE 'synchronized[[:space:]]*\(|synchronized[[:space:]]+[a-zA-Z]'; then
        ASK_REASONS+=("synchronized blocks can pin virtual threads (default in v4). Consider ReentrantLock.")
    fi
    if echo "$CONTENT" | grep -qE '\.and\(\)[[:space:]]*\.'; then
        DENY_REASONS+=(".and() chaining removed in Security 7. Use lambda DSL exclusively.")
    fi
    if echo "$CONTENT" | grep -qE 'import[[:space:]]+com\.fasterxml\.jackson'; then
        ASK_REASONS+=("Jackson 3 is default in v4. Use JsonMapper. Set spring.jackson.use-jackson2-defaults=true for compat.")
    fi
    if echo "$CONTENT" | grep -qE '@MockBean|@SpyBean'; then
        if ! echo "$CONTENT" | grep -qE '@MockitoBean|@MockitoSpyBean'; then
            DENY_REASONS+=("@MockBean/@SpyBean removed. Use @MockitoBean/@MockitoSpyBean.")
        fi
    fi
fi

# --- Security patterns (all versions, skip test files) — DENY: security-critical ---
if [ "$_IS_CONFIG" = "false" ] && [ "$_IS_TEST" = "false" ]; then
    if echo "$CONTENT" | grep -qE '@Autowired[[:space:]]+(private|protected)[[:space:]]'; then
        ASK_REASONS+=("@Autowired field injection detected. Use constructor injection (immutable, testable).")
    fi
    if echo "$CONTENT" | grep -qE 'csrf[[:space:]]*\([[:space:]]*csrf[[:space:]]*->[[:space:]]*csrf\.disable'; then
        DENY_REASONS+=("CSRF protection disabled. Required by default in Security 7. Only disable for stateless Bearer-token APIs.")
    fi
    if echo "$CONTENT" | grep -qE 'allowedOrigins[[:space:]]*\([[:space:]]*"\*"'; then
        DENY_REASONS+=("CORS allowedOrigins(\"*\") is a misconfiguration. Specify explicit origins.")
    fi
    if echo "$CONTENT" | grep -qE '@RequestBody[[:space:]]+[A-Z]' && ! echo "$CONTENT" | grep -qE '@Valid[[:space:]]+@RequestBody|@Validated[[:space:]]+@RequestBody'; then
        ASK_REASONS+=("@RequestBody without @Valid. Add @Valid for input validation.")
    fi
    if [ "$SB_VERSION" -ge 4 ] 2>/dev/null && echo "$CONTENT" | grep -qE 'AntPathRequestMatcher|MvcRequestMatcher'; then
        DENY_REASONS+=("AntPathRequestMatcher/MvcRequestMatcher removed in Security 7. Use PathPatternRequestMatcher.")
    fi
    if echo "$CONTENT" | grep -qiE '(password|secret|apiKey|api_key)[[:space:]]*=[[:space:]]*"[^$"]'; then
        DENY_REASONS+=("Hardcoded credential detected. Use @ConfigurationProperties or environment variables.")
    fi
    if echo "$CONTENT" | grep -qE 'System\.(out|err)\.print'; then
        ASK_REASONS+=("System.out/err detected. Use SLF4J (LoggerFactory.getLogger) for structured logging.")
    fi
    if echo "$CONTENT" | grep -qE '@Value[[:space:]]*\([[:space:]]*"[$][{]'; then
        if echo "$CONTENT" | grep -qE '@Service|@Component|@Repository'; then
            ASK_REASONS+=("@Value in service/component. Use @ConfigurationProperties for type-safe config.")
        fi
    fi
    if [ "$SB_VERSION" -ge 4 ] 2>/dev/null && echo "$CONTENT" | grep -qE 'import[[:space:]]+org\.springframework\.lang\.Nullable'; then
        ASK_REASONS+=("org.springframework.lang.Nullable deprecated. Use org.jspecify.annotations.Nullable.")
    fi
    if [ "$SB_VERSION" -ge 4 ] 2>/dev/null && echo "$CONTENT" | grep -qE 'HttpMessageConverters[[:space:]]+[a-z]|HttpMessageConverters\(\)'; then
        DENY_REASONS+=("HttpMessageConverters removed. Use ServerHttpMessageConvertersCustomizer.")
    fi
    if [ "$SB_VERSION" -ge 4 ] 2>/dev/null && echo "$CONTENT" | grep -qE 'spring-boot-starter-aop'; then
        ASK_REASONS+=("spring-boot-starter-aop renamed to spring-boot-starter-aspectj.")
    fi
fi

# --- Config file patterns (yml/yaml/properties) ---
if [ "$_IS_CONFIG" = "true" ]; then
    if echo "$CONTENT" | grep -iE '(password|secret|token|api-key)[[:space:]]*[:=]' | grep -qvE '[$][{]|^[[:space:]]*#'; then
        DENY_REASONS+=("Potential hardcoded secret in config file. Use environment variable placeholders: \${ENV_VAR}.")
    fi
    if echo "$CONTENT" | grep -qE 'exposure\.(include|web\.exposure\.include)[[:space:]]*[:=][[:space:]]*\*'; then
        DENY_REASONS+=("Actuator endpoints exposed with wildcard (*). Expose only: health, info, prometheus.")
    fi
    if echo "$CONTENT" | grep -qE '\{noop\}'; then
        DENY_REASONS+=("{noop} password encoding detected. Use bcrypt or argon2 in production.")
    fi
    if [ "$SB_VERSION" -ge 4 ] 2>/dev/null && echo "$CONTENT" | grep -qE 'management\.tracing\.enabled'; then
        ASK_REASONS+=("management.tracing.enabled renamed to management.tracing.export.enabled.")
    fi
fi

# --- Output: deny wins over ask, all violations reported (#171) ---
if [ ${#DENY_REASONS[@]} -gt 0 ]; then
    ALL=("${DENY_REASONS[@]}" "${ASK_REASONS[@]}")
    COMBINED=$(printf '• %s\n' "${ALL[@]}")
    _cc_security_log "DENY" "spring-boot-version-guard" "${COMBINED} | file=${FILE_PATH}"
    _cc_json_pretool_deny_structured "$COMBINED" "security" "true"
elif [ ${#ASK_REASONS[@]} -gt 0 ]; then
    COMBINED=$(printf '• %s\n' "${ASK_REASONS[@]}")
    _cc_security_log "ASK" "spring-boot-version-guard" "${COMBINED} | file=${FILE_PATH}"
    _cc_json_pretool_ask "$COMBINED"
fi

exit 0
