#!/bin/bash
# cognitive-core hook: PreToolUse (Write, Edit)
# Angular version-aware pattern enforcement
# Detects Angular version from package.json and warns about deprecated patterns
# Uses "ask" (not "deny") — graduated response per framework philosophy
# All patterns use POSIX ERE (no \s, \b, \w) for macOS + Linux compatibility
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_lib.sh"
_cc_load_config

# Only activate for Angular projects
[ "${CC_LANGUAGE:-}" = "angular" ] || exit 0

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

# Only check TypeScript and HTML files
case "$FILE_PATH" in
    *.ts|*.html) ;;
    *) exit 0 ;;
esac

# Skip test/spec files
case "$FILE_PATH" in
    *.spec.ts|*.test.ts) exit 0 ;;
esac

[ -z "$CONTENT" ] && exit 0

# --- Detect Angular version (project-local cache with mtime invalidation, #176) ---
NG_VERSION=$(_cc_version_cache_get "angular" "package.json")

if [ -z "$NG_VERSION" ]; then
    NG_VERSION=0
    if [ -f "${CC_PROJECT_DIR}/package.json" ]; then
        NG_VERSION=$(grep '"@angular/core"' "${CC_PROJECT_DIR}/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
        NG_VERSION=${NG_VERSION:-0}
    fi
    _cc_version_cache_set "angular" "$NG_VERSION"
fi

[ "$NG_VERSION" -eq 0 ] && exit 0

DENY_REASONS=()
ASK_REASONS=()

# --- v18+ patterns — ASK: deprecated but functional ---
if [ "$NG_VERSION" -ge 18 ]; then
    if echo "$CONTENT" | grep -qE '@NgModule'; then
        case "$FILE_PATH" in
            *app.module.ts|*app.config.ts) ;;
            *) ASK_REASONS+=("Use standalone components instead of @NgModule (modern pattern since v14+).") ;;
        esac
    fi
    if echo "$CONTENT" | grep -qE '\*ngIf|\*ngFor|\*ngSwitch'; then
        ASK_REASONS+=("Use built-in control flow (@if, @for, @switch) instead of *ngIf/*ngFor/*ngSwitch.")
    fi
    if echo "$CONTENT" | grep -qE 'HttpClientModule'; then
        ASK_REASONS+=("Use provideHttpClient() instead of HttpClientModule.")
    fi
    if echo "$CONTENT" | grep -qE 'implements[[:space:]]+HttpInterceptor'; then
        ASK_REASONS+=("Use HttpInterceptorFn (functional) instead of class-based HttpInterceptor.")
    fi
fi

# --- v19+ patterns — ASK ---
if [ "$NG_VERSION" -ge 19 ]; then
    if echo "$CONTENT" | grep -qE '@Input\(\)|@Output\(\)'; then
        ASK_REASONS+=("Use input()/output() signal APIs instead of @Input()/@Output() decorators.")
    fi
    if echo "$CONTENT" | grep -qE 'CommonModule'; then
        ASK_REASONS+=("CommonModule not needed. Built-in control flow and standalone pipes replace it.")
    fi
fi

# --- v20+ patterns — ASK ---
if [ "$NG_VERSION" -ge 20 ]; then
    if echo "$CONTENT" | grep -qE "import[[:space:]]+'zone\.js'|import[[:space:]]+\"zone\.js\""; then
        ASK_REASONS+=("Zone.js no longer needed. Use provideZonelessChangeDetection().")
    fi
    if echo "$CONTENT" | grep -qE 'NgZone'; then
        ASK_REASONS+=("NgZone deprecated with zoneless. Use signals and effect().")
    fi
    if echo "$CONTENT" | grep -qE 'afterRender[[:space:]]*\('; then
        if ! echo "$CONTENT" | grep -qE 'afterRenderEffect\(|afterEveryRender\(|afterNextRender\('; then
            ASK_REASONS+=("afterRender() renamed to afterEveryRender() in v20.")
        fi
    fi
    if echo "$CONTENT" | grep -qE '@angular-devkit/build-angular'; then
        ASK_REASONS+=("@angular-devkit/build-angular replaced by @angular/build (saves ~200MB).")
    fi
fi

# --- v21+ patterns — ASK ---
if [ "$NG_VERSION" -ge 21 ]; then
    if echo "$CONTENT" | grep -qE 'karma\.conf|karma-'; then
        ASK_REASONS+=("Karma removed in v21. Vitest is the default test runner.")
    fi
    if echo "$CONTENT" | grep -qE 'provideHttpClient\(\)'; then
        if ! echo "$CONTENT" | grep -qE 'provideHttpClient\(with'; then
            ASK_REASONS+=("HttpClient is auto-provided. provideHttpClient() only needed with withInterceptors().")
        fi
    fi
fi

# --- Security patterns (all versions) — DENY: XSS, injection, secrets ---
if echo "$CONTENT" | grep -qE 'bypassSecurityTrust(Html|Url|Script|Style|ResourceUrl)'; then
    DENY_REASONS+=("bypassSecurityTrust detected — XSS bypass. Use a sanitization pipe with tests.")
fi
if echo "$CONTENT" | grep -qE '\[innerHTML\]'; then
    DENY_REASONS+=("[innerHTML] binding — XSS risk if user-controlled. Prefer Angular template syntax.")
fi
if echo "$CONTENT" | grep -qE '(^|[[:space:];])eval[[:space:]]*\(|document\.write[[:space:]]*\(|new[[:space:]]+Function[[:space:]]*\('; then
    DENY_REASONS+=("eval()/document.write()/new Function() — code injection. Use Angular APIs instead.")
fi
if echo "$FILE_PATH" | grep -qE 'environment[^/]*\.ts$'; then
    if echo "$CONTENT" | grep -qiE '(api[_-]?key|secret|password|token)[[:space:]]*[:=]'; then
        DENY_REASONS+=("Secret in environment file — compiled into browser bundle. Use InjectionToken + runtime config.")
    fi
fi

# --- Output: deny wins over ask, all violations reported (#171) ---
if [ ${#DENY_REASONS[@]} -gt 0 ]; then
    ALL=("${DENY_REASONS[@]}" "${ASK_REASONS[@]}")
    COMBINED=$(printf '• %s\n' "${ALL[@]}")
    _cc_security_log "DENY" "angular-version-guard" "${COMBINED} | file=${FILE_PATH}"
    _cc_json_pretool_deny_structured "$COMBINED" "security" "true"
elif [ ${#ASK_REASONS[@]} -gt 0 ]; then
    COMBINED=$(printf '• %s\n' "${ASK_REASONS[@]}")
    _cc_security_log "ASK" "angular-version-guard" "${COMBINED} | file=${FILE_PATH}"
    _cc_json_pretool_ask "$COMBINED"
fi

exit 0
