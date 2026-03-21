#!/bin/bash
# Test suite: Recursive epic structure validation
# Validates that epic issues have proper sub-issue links, dependency declarations,
# parent references, and effort estimates — required for EU AI Act governance.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "16 — Recursive Epic Structure"

# --- Test data ---
TEST_DIR=$(create_test_dir)

# Well-formed epic
cat > "${TEST_DIR}/epic-good.md" << 'EOF'
## Epic: Test Epic

| Issue | Title | Size | Effort | Type | Dependencies | Article |
|-------|-------|------|--------|------|-------------|---------|
| #101 | First task | S | 1.5h | AI | None | Art. 50(1) |
| #102 | Second task | M | 3h | human+AI | #101 | Art. 12(1) |
| #103 | Third task | L | 8h | human+AI | #101, #102 | Art. 15(5) |

### Dependency Graph

#101 --> #102 --> #103

### Effort Summary

| Sub-Epic | Priority | Issues | Hours |
|----------|----------|--------|-------|
| Total | P0 | 3 | 12.5h |
EOF

# Well-formed sub-issue
cat > "${TEST_DIR}/sub-issue-good.md" << 'EOF'
**Parent**: #100 (Test Epic)
**Type**: human+AI
**Total effort**: 3h

### Acceptance Criteria

| # | Criterion | Est. | Type |
|---|-----------|------|------|
| 1 | First criterion | 30min | AI |
| 2 | Second criterion | 45min | human+AI |

### Dependencies
- #101

### Files to Modify
- core/hooks/_lib.sh
EOF

# Bad epic (no sub-issue table)
cat > "${TEST_DIR}/epic-bad.md" << 'EOF'
## Epic: Bad Epic
Some description without sub-issue table.
EOF

# Bad sub-issue (no parent)
cat > "${TEST_DIR}/sub-issue-bad.md" << 'EOF'
**Type**: AI
**Total effort**: 1h
No parent reference here.
EOF

EPIC_GOOD=$(cat "${TEST_DIR}/epic-good.md")
SUB_GOOD=$(cat "${TEST_DIR}/sub-issue-good.md")
EPIC_BAD=$(cat "${TEST_DIR}/epic-bad.md")
SUB_BAD=$(cat "${TEST_DIR}/sub-issue-bad.md")

# ================================================================
# Epic structure tests
# ================================================================

assert_contains \
    "Epic has sub-issue reference table" \
    "$EPIC_GOOD" \
    "| Issue | Title | Size | Effort | Type | Dependencies |"

assert_contains \
    "Epic references sub-issue #101" \
    "$EPIC_GOOD" \
    "#101"

assert_contains \
    "Epic references sub-issue #102" \
    "$EPIC_GOOD" \
    "#102"

assert_contains \
    "Epic references sub-issue #103" \
    "$EPIC_GOOD" \
    "#103"

assert_contains \
    "Epic has dependency graph" \
    "$EPIC_GOOD" \
    "Dependency Graph"

assert_contains \
    "Epic has effort summary" \
    "$EPIC_GOOD" \
    "Effort Summary"

assert_contains \
    "Epic effort summary has hours" \
    "$EPIC_GOOD" \
    "Hours"

# ================================================================
# Sub-issue structure tests
# ================================================================

assert_contains \
    "Sub-issue has parent reference" \
    "$SUB_GOOD" \
    "**Parent**: #100"

assert_contains \
    "Sub-issue has acceptance criteria table with effort" \
    "$SUB_GOOD" \
    "| # | Criterion | Est. | Type |"

assert_contains \
    "Sub-issue has per-criterion effort estimate" \
    "$SUB_GOOD" \
    "30min"

assert_contains \
    "Sub-issue has total effort" \
    "$SUB_GOOD" \
    "**Total effort**:"

assert_contains \
    "Sub-issue has dependencies section" \
    "$SUB_GOOD" \
    "Dependencies"

assert_contains \
    "Sub-issue has files to modify" \
    "$SUB_GOOD" \
    "Files to Modify"

assert_contains \
    "Sub-issue has task type" \
    "$SUB_GOOD" \
    "**Type**:"

# ================================================================
# Bad structure detection tests
# ================================================================

assert_not_contains \
    "Bad epic detected: no sub-issue table" \
    "$EPIC_BAD" \
    "| Issue | Title |"

assert_not_contains \
    "Orphan sub-issue detected: no parent reference" \
    "$SUB_BAD" \
    "**Parent**:"

# ================================================================
# Validate actual EU AI Act recursive epic (if co-located)
# ================================================================
EPIC_FILE="${ROOT_DIR}/../dev-notes/docs/research/2026-03-21-eu-ai-act-recursive-epic.md"
if [ -f "$EPIC_FILE" ]; then
    EPIC_CONTENT=$(cat "$EPIC_FILE")
    assert_contains "Actual epic has dependency graph" "$EPIC_CONTENT" "Dependency Graph"
    assert_contains "Actual epic has dependency matrix" "$EPIC_CONTENT" "Dependency Matrix"
    assert_contains "Actual epic references parent #120" "$EPIC_CONTENT" "#120"
    assert_contains "Actual epic references sub-issue #121" "$EPIC_CONTENT" "#121"
    assert_contains "Actual epic has effort summary" "$EPIC_CONTENT" "Effort Summary"
    assert_contains "Actual epic has GitHub links" "$EPIC_CONTENT" "github.com/mindcockpit-ai/cognitive-core/issues"
else
    _skip "EU AI Act recursive epic not found (dev-notes may not be co-located)"
fi

suite_end
