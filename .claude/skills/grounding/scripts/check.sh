#!/bin/bash
# grounding engine entry point (ADR-001). Reads text on stdin, writes an
# advisory report on stdout, always exits 0. Layers are added by #434/#436.
set -euo pipefail

GROUNDING_VERSION="0.1.0"
GROUNDING_SCHEMA="1"

case "${1:-}" in
    --version)
        printf 'grounding %s schema=%s\n' "$GROUNDING_VERSION" "$GROUNDING_SCHEMA"
        exit 0
        ;;
    "") ;;
    *)
        printf 'Usage: check.sh [--version] < text\n' >&2
        exit 0
        ;;
esac

# Same input cap as validate-prompt.sh (64KB)
head -c 65536 > /dev/null
printf 'Grounding engine %s: no layers enabled yet\n' "$GROUNDING_VERSION"
exit 0
