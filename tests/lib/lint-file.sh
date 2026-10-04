#!/bin/bash
# Lint one file for the post-edit hook (CC_LINT_COMMAND, #375).
# .sh: ShellCheck at the blocking severity (bash -n without ShellCheck)
# .py: compile only, no bytecode written
# Prints findings; silent when clean.
set -euo pipefail

file="${1:?usage: lint-file.sh <file>}"

case "$file" in
    *.sh)
        if command -v shellcheck >/dev/null 2>&1; then
            shellcheck -S warning -f gcc "$file" || true
        else
            bash -n "$file" 2>&1 || true
        fi
        ;;
    *.py)
        python3 - "$file" 2>&1 <<'PY' || true
import sys
path = sys.argv[1]
try:
    with open(path, "rb") as f:
        compile(f.read(), path, "exec")
except SyntaxError as e:
    print(f"{path}:{e.lineno}: {e.msg}")
PY
        ;;
esac
