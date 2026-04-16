# Continuation Prompt — 2026-04-16

Paste this into a new Claude Code session on the other machine after `git pull`.

---

Read the session document at `docs/sessions/2026-04-16-conf-escaping-and-board-hygiene.md` for full context. Here is what needs to happen next:

## Immediate (this session)

1. **Merge PR #251** (`chore/232-disable-default-coauthored-by`) — sets `includeCoAuthoredBy: false` in settings.json and template. Review, merge, switch back to main.

2. **Fix #246** (P1 — SIGPIPE race in test-helpers.sh) — 2-line fix in `tests/lib/test-helpers.sh`:
   - `assert_contains()` line 125: replace `echo "$haystack" | grep -qF "$needle"` with `grep -qF "$needle" <<< "$haystack"`
   - `assert_not_contains()` line 134: same pattern
   - This fixes flaky suite 07 and deterministic failures in suite 14 (6 SKILL.md assertions)
   - Create branch `fix/246-sigpipe-assert-contains`, commit, push, PR, verify suites 07 and 14 pass

3. **Fix #247** (P2 — macOS timeout/md5sum) — portable wrappers needed:
   - Suite 21: `md5sum` → `md5 -r` on macOS fallback
   - Suite 12: `timeout` → skip with `_skip` if unavailable (or use perl alarm fallback)
   - Suite 14 ReDoS test: same timeout fix
   - Create branch `fix/247-macos-test-portability`

4. **Fix #248** (P3 — suite 16 stale assertions) — remove or skip the external file validation section at lines 169-183 in `tests/suites/16-recursive-epic-structure.sh`. The synthetic tests (lines 1-167) already cover structural validation.

## After test fixes

5. **Run `bash tests/run-all.sh`** — target: 21/21 suites passing

## Backlog

6. **#245** (board hygiene hook) — full architecture and AC defined in the ticket. Ready for implementation when prioritized. Size:M, ~200 lines across 4 files.

7. **#232** (custom Co-Authored-By trailer) — the `includeCoAuthoredBy: false` is a stopgap. The full `prepare-commit-msg` hook with `CC_COAUTHOR_LINE` config is still pending.
