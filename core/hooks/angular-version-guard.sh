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

# --- Detect Angular version (cached per session) ---
_NG_VERSION_CACHE="/tmp/cc_angular_version_${CC_PROJECT_DIR##*/}"
NG_VERSION=0

if [ -f "$_NG_VERSION_CACHE" ]; then
    NG_VERSION=$(cat "$_NG_VERSION_CACHE")
else
    if [ -f "${CC_PROJECT_DIR}/package.json" ]; then
        NG_VERSION=$(grep '"@angular/core"' "${CC_PROJECT_DIR}/package.json" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
        NG_VERSION=${NG_VERSION:-0}
        echo "$NG_VERSION" > "$_NG_VERSION_CACHE"
    fi
fi

[ "$NG_VERSION" -eq 0 ] && exit 0

REASON=""

# --- v18+ patterns ---
if [ "$NG_VERSION" -ge 18 ]; then
    # Warn about NgModule declarations in feature code
    if echo "$CONTENT" | grep -qE '@NgModule'; then
        case "$FILE_PATH" in
            *app.module.ts|*app.config.ts) ;;  # Root module is acceptable
            *) REASON="Angular v${NG_VERSION}: Use standalone components instead of @NgModule. Standalone is the modern pattern since v14+." ;;
        esac
    fi

    # Warn about legacy structural directives
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '\*ngIf|\*ngFor|\*ngSwitch'; then
        REASON="Angular v${NG_VERSION}: Use built-in control flow (@if, @for, @switch) instead of *ngIf/*ngFor/*ngSwitch. Run: ng generate @angular/core:control-flow"
    fi

    # Warn about HttpClientModule
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'HttpClientModule'; then
        REASON="Angular v${NG_VERSION}: Use provideHttpClient() instead of HttpClientModule. Module-based HTTP setup is deprecated."
    fi

    # Warn about class-based interceptors
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'implements[[:space:]]+HttpInterceptor'; then
        REASON="Angular v${NG_VERSION}: Use HttpInterceptorFn (functional interceptor) instead of class-based HttpInterceptor."
    fi
fi

# --- v19+ patterns ---
if [ "$NG_VERSION" -ge 19 ] && [ -z "$REASON" ]; then
    # Warn about @Input/@Output decorators (signal APIs are stable in v19)
    if echo "$CONTENT" | grep -qE '@Input\(\)|@Output\(\)'; then
        REASON="Angular v${NG_VERSION}: Use input()/input.required()/output() signal APIs instead of @Input()/@Output() decorators. Signal APIs are stable since v19."
    fi

    # Warn about CommonModule import (not needed with built-in control flow)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'CommonModule'; then
        REASON="Angular v${NG_VERSION}: CommonModule is not needed. Built-in control flow (@if, @for) and standalone pipes replace it."
    fi
fi

# --- v20+ patterns ---
if [ "$NG_VERSION" -ge 20 ] && [ -z "$REASON" ]; then
    # Warn about Zone.js imports
    if echo "$CONTENT" | grep -qE "import[[:space:]]+'zone\.js'|import[[:space:]]+\"zone\.js\""; then
        REASON="Angular v${NG_VERSION}: Zone.js is no longer needed. Use provideZonelessChangeDetection() and signal-based reactivity."
    fi

    # Warn about NgZone usage
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'NgZone'; then
        REASON="Angular v${NG_VERSION}: NgZone is deprecated with zoneless change detection. Use signals and effect() instead."
    fi

    # Warn about renamed afterRender()
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'afterRender[[:space:]]*\('; then
        if ! echo "$CONTENT" | grep -qE 'afterRenderEffect\(|afterEveryRender\(|afterNextRender\('; then
            REASON="Angular v${NG_VERSION}: afterRender() was renamed to afterEveryRender() in v20."
        fi
    fi

    # Warn about @angular-devkit/build-angular (replaced by @angular/build)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '@angular-devkit/build-angular'; then
        REASON="Angular v${NG_VERSION}: @angular-devkit/build-angular is replaced by @angular/build (saves ~200MB)."
    fi
fi

# --- v21+ patterns ---
if [ "$NG_VERSION" -ge 21 ] && [ -z "$REASON" ]; then
    # Warn about Karma/Jest (deprecated in v21, Vitest is default)
    if echo "$CONTENT" | grep -qE 'karma\.conf|karma-'; then
        REASON="Angular v${NG_VERSION}: Karma is removed. Vitest is the default test runner. Migrate to Vitest."
    fi

    # Info about provideHttpClient() being optional
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE 'provideHttpClient\(\)'; then
        # Only warn if it's provideHttpClient() with no arguments
        if ! echo "$CONTENT" | grep -qE 'provideHttpClient\(with'; then
            REASON="Angular v${NG_VERSION}: HttpClient is auto-provided. provideHttpClient() is only needed when passing options like withInterceptors()."
        fi
    fi
fi

# --- Security patterns (all versions) ---
if [ -z "$REASON" ]; then
    # bypassSecurityTrust (DomSanitizer bypass)
    if echo "$CONTENT" | grep -qE 'bypassSecurityTrust(Html|Url|Script|Style|ResourceUrl)'; then
        REASON="Angular security: bypassSecurityTrust detected. Use a dedicated sanitization pipe with tests and a SECURITY comment referencing the issue tracker."
    fi

    # innerHTML with interpolation (potential XSS)
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '\[innerHTML\]'; then
        REASON="Angular security: [innerHTML] binding detected. Ensure the value is not user-controlled. Prefer Angular template syntax."
    fi

    # eval / document.write / new Function
    if [ -z "$REASON" ] && echo "$CONTENT" | grep -qE '(^|[[:space:];])eval[[:space:]]*\(|document\.write[[:space:]]*\(|new[[:space:]]+Function[[:space:]]*\('; then
        REASON="Angular security: eval()/document.write()/new Function() detected. These enable XSS — use Angular APIs instead."
    fi

    # Secrets in environment.ts
    if [ -z "$REASON" ] && echo "$FILE_PATH" | grep -qE 'environment[^/]*\.ts$'; then
        if echo "$CONTENT" | grep -qiE '(api[_-]?key|secret|password|token)[[:space:]]*[:=]'; then
            REASON="Angular security: potential secret in environment file. Use InjectionToken + runtime config — environment.ts is compiled into the bundle."
        fi
    fi
fi

# Output ask JSON if pattern found, otherwise silent exit 0
if [ -n "$REASON" ]; then
    _cc_security_log "ASK" "angular-version-guard" "${REASON} | file=${FILE_PATH}"
    _cc_json_pretool_ask "$REASON"
fi

exit 0
