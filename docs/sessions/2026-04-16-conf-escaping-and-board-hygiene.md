# Session: 2026-04-16 — Conf Escaping, Board Hygiene, Test Investigation

## Completed

### fix(install): unescaped $1 in generated conf (#244) — DONE

**Problem**: `install.sh` generates `cognitive-core.conf` with unescaped `$1` in command variables (e.g. `CC_LINT_COMMAND="eslint $1"`). When sourced under `set -u`, bash throws `unbound variable`.

**Root cause**: Unquoted heredoc (`<< CONFEOF`) expands `$1` when writing conf. The case statement uses single quotes correctly, but the heredoc pass-through strips the protection.

**Fix** (2 files, 19 lines):
- `install.sh`: Escapes `$` in `CC_LINT_COMMAND`, `CC_TEST_COMMAND`, `CC_FORMAT_COMMAND` before heredoc write
- `update.sh`: Migration `_cc_fix_unescaped_dollar()` patches existing broken conf files before sourcing — idempotent, cross-platform (`sed -i.bak`)

**Also fixed**: `brigadee/cognitive-core.conf` patched directly (`"eslint $1"` → `"eslint \$1"`)

**Status**: PR #249 merged, issue #244 approved and moved to Done.

### chore(hooks): disable default Co-Authored-By (#232 partial)

**Problem**: Claude Code adds default `Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>` trailer, violating CLAUDE.md rule 7 ("NO AI references").

**Fix**: Set `includeCoAuthoredBy: false` in:
- `.claude/settings.json` (this project)
- `core/templates/settings.json.tmpl` (all future installations)

**Status**: PR #251 open on branch `chore/232-disable-default-coauthored-by`. Ready for merge.

## Created (not started)

### feat(hooks): pre-commit board hygiene guard (#245) — Backlog

Full architecture designed and reviewed from testability, performance, usability, and stochastic vulnerability perspectives. Key decisions:
- Separate hook (`validate-commit.sh`), not inline in `validate-bash.sh`
- Flat TSV cache (no jq in hot path), refreshed at session start
- Three deterministic states: allow / deny / ask — no silent fail-open
- Network/API issues escalate to `ask` ("validate manually"), never silently allow
- Pure decision function `_cc_board_validate()` for testability
- 24 acceptance criteria, 38 test cases defined in ticket

### Test suite failures investigated (#246, #247, #248) — Backlog

Investigated all 5 pre-existing test suite failures (07, 12, 14, 16, 21). Found 3 root causes:

| Issue | Root Cause | Suites | Priority |
|-------|-----------|--------|----------|
| #246 | SIGPIPE race: `echo \| grep -q` + `pipefail` on large inputs | 07, 14 | P1 |
| #247 | `timeout`/`md5sum` missing on macOS | 12, 14, 21 | P2 |
| #248 | Stale external file assertions in suite 16 | 16 | P3 |

**#246 fix** is 2 lines in `test-helpers.sh`: replace `echo "$haystack" | grep -qF` with `grep -qF "$needle" <<< "$haystack"` (herestring avoids SIGPIPE). This fixes the systemic issue across all suites.

## Open Branches

| Branch | PR | Status |
|--------|-----|--------|
| `chore/232-disable-default-coauthored-by` | #251 | Open, ready for merge |
| `fix/244-conf-unescaped-dollar` | #249 | Merged |

## Current State

- On branch: `chore/232-disable-default-coauthored-by`
- Working tree: clean
- Main is up to date (includes #244 merge)

## Board Summary

| Issue | Status | Column |
|-------|--------|--------|
| #244 | Closed | Done |
| #245 | Open | Backlog |
| #246 | Open | Backlog |
| #247 | Open | Backlog |
| #248 | Open | Backlog |
