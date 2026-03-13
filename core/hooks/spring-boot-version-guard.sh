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

# Only check Java, Kotlin, and XML files
case "$FILE_PATH" in
    *.java|*.kt|*.xml) ;;
    *) exit 0 ;;
esac

# Skip test files
case "$FILE_PATH" in
    *Test.java|*Tests.java|*IT.java) exit 0 ;;
esac
# Skip files under test directories
case "$FILE_PATH" in
    */test/*|*/tests/*) exit 0 ;;
esac

[ -z "$CONTENT" ] && exit 0

# --- Detect Spring Boot version (cached per session) ---
_SB_VERSION_CACHE="/tmp/cc_spring_boot_version_${CC_PROJECT_DIR##*/}"
SB_VERSION=0

if [ -f "$_SB_VERSION_CACHE" ]; then
    SB_VERSION=$(cat "$_SB_VERSION_CACHE")
else
    # Try pom.xml first
    if [ -f "${CC_PROJECT_DIR}/pom.xml" ]; then
        SB_VERSION=$(grep -A2 'spring-boot-starter-parent' "${CC_PROJECT_DIR}/pom.xml" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
    fi
    # Fall back to build.gradle
    if [ -z "$SB_VERSION" ] || [ "$SB_VERSION" = "0" ]; then
        if [ -f "${CC_PROJECT_DIR}/build.gradle" ]; then
            SB_VERSION=$(grep 'org.springframework.boot' "${CC_PROJECT_DIR}/build.gradle" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
        fi
    fi
    # Fall back to build.gradle.kts
    if [ -z "$SB_VERSION" ] || [ "$SB_VERSION" = "0" ]; then
        if [ -f "${CC_PROJECT_DIR}/build.gradle.kts" ]; then
            SB_VERSION=$(grep 'org.springframework.boot' "${CC_PROJECT_DIR}/build.gradle.kts" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
        fi
    fi
    SB_VERSION=${SB_VERSION:-0}
    echo "$SB_VERSION" > "$_SB_VERSION_CACHE"
fi

[ "$SB_VERSION" -eq 0 ] && exit 0

REASON=""

# --- v3+ patterns (javax to jakarta, Security 6) ---
if [ "$SB_VERSION" -ge 3 ]; then
    # Warn about javax.* imports (must use jakarta.*)
    if echo "$CONTENT" | grep -qE 'import[[:space:]]+javax\.(persistence|validation|servlet|annotation|mail|transaction|inject|enterprise)'; then
        REASON="Spring Boot v${SB_VERSION}: Use jakarta.* imports instead of javax.* — Jakarta EE 10 namespace is required since Spring Boot 3.0."
    fi

    # Warn about WebSecurityConfigurerAdapter (removed in Security 6)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'WebSecurityConfigurerAdapter'; then
        REASON="Spring Boot v${SB_VERSION}: WebSecurityConfigurerAdapter was removed in Spring Security 6. Use @Bean SecurityFilterChain with HttpSecurity parameter instead."
    fi

    # Warn about antMatchers (removed in Security 6)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '\.antMatchers[[:space:]]*\('; then
        REASON="Spring Boot v${SB_VERSION}: antMatchers() was removed in Spring Security 6. Use requestMatchers() instead."
    fi

    # Warn about authorizeRequests (replaced by authorizeHttpRequests)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '\.authorizeRequests[[:space:]]*\('; then
        REASON="Spring Boot v${SB_VERSION}: authorizeRequests() is deprecated. Use authorizeHttpRequests() with the lambda DSL."
    fi
fi

# --- v3.2+ patterns (RestClient, virtual threads) ---
if [ "$SB_VERSION" -ge 3 ] && [ -z "$REASON" ]; then
    # Warn about RestTemplate usage (suggest RestClient)
    if echo "$CONTENT" | grep -qE 'new[[:space:]]+RestTemplate[[:space:]]*\(|RestTemplate[[:space:]]+restTemplate'; then
        REASON="Spring Boot v${SB_VERSION}: Consider using RestClient instead of RestTemplate. RestClient is the modern synchronous HTTP client since v3.2. RestTemplate is in maintenance mode."
    fi

    # Warn about Thread.sleep in production code
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'Thread[[:space:]]*\.[[:space:]]*sleep[[:space:]]*\('; then
        REASON="Spring Boot v${SB_VERSION}: Avoid Thread.sleep() in production code. Use @Scheduled, CompletableFuture, or virtual threads (spring.threads.virtual.enabled=true) instead."
    fi
fi

# --- v4+ patterns (Java 21 required, Security 7, Jackson 3) ---
if [ "$SB_VERSION" -ge 4 ] && [ -z "$REASON" ]; then
    # Warn about synchronized blocks (virtual thread pinning)
    if echo "$CONTENT" | grep -qE 'synchronized[[:space:]]*\(|synchronized[[:space:]]+[a-zA-Z]'; then
        REASON="Spring Boot v${SB_VERSION}: synchronized blocks can pin virtual threads (default in v4). Consider using ReentrantLock or java.util.concurrent alternatives."
    fi

    # Warn about deprecated Security APIs from v3
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '\.and\(\)[[:space:]]*\.' ; then
        REASON="Spring Boot v${SB_VERSION}: The .and() chaining pattern is removed in Spring Security 7. Use the lambda DSL exclusively."
    fi

    # Warn about RestTemplate (deprecated in v4, removal planned in Spring Framework 8)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'new[[:space:]]+RestTemplate[[:space:]]*\(|RestTemplate[[:space:]]+restTemplate'; then
        REASON="Spring Boot v${SB_VERSION}: RestTemplate is deprecated. Use RestClient (blocking) or WebClient (reactive). RestTemplate removal is planned in Spring Framework 8."
    fi

    # Warn about Jackson 2 package (replaced by Jackson 3 in v4)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'import[[:space:]]+com\.fasterxml\.jackson'; then
        REASON="Spring Boot v${SB_VERSION}: Jackson 3 is the default (package: tools.jackson). Use JsonMapper instead of ObjectMapper. Set spring.jackson.use-jackson2-defaults=true for temporary compatibility."
    fi

    # Warn about removed @MockBean/@SpyBean
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '@MockBean|@SpyBean'; then
        if ! echo "$CONTENT" | grep -qE '@MockitoBean|@MockitoSpyBean'; then
            REASON="Spring Boot v${SB_VERSION}: @MockBean/@SpyBean are removed. Use @MockitoBean/@MockitoSpyBean (Mockito native annotations) instead."
        fi
    fi
fi

# Output ask JSON if pattern found, otherwise silent exit 0
if [ -n "$REASON" ]; then
    _cc_security_log "ASK" "spring-boot-version-guard" "${REASON} | file=${FILE_PATH}"
    _cc_json_pretool_ask "$REASON"
fi

exit 0
