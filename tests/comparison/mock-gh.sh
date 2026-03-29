#!/bin/bash
# Mock gh CLI for comparison test
# Logs all calls and returns fixed responses
set -uo pipefail

LOG="${MOCK_GH_LOG:-/tmp/cc-comparison-gh-calls.log}"
echo "$(date +%s) gh $*" >> "$LOG"

case "$*" in
    *"issue list"*"search"*"EW Index"*)
        echo '[{"number":42,"title":"[smoke-test] EW Index: ORA-00904"}]'
        ;;
    *"issue list"*"search"*"MPMF"*)
        echo '[]'
        ;;
    *"issue list"*"smoke-test"*"open"*)
        echo '[{"number":42,"title":"[smoke-test] EW Index: ORA-00904","url":"https://github.com/test-org/test-repo/issues/42"}]'
        ;;
    *"issue create"*)
        echo "https://github.com/test-org/test-repo/issues/99"
        ;;
    *"project item-add"*)
        echo "Added"
        ;;
    *)
        echo "[]"
        ;;
esac
