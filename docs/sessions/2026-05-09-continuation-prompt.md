# Continuation prompt — picking up after 2026-05-05→08 session

Reference: `docs/sessions/2026-05-05-to-08-session.md`.

## Open work — drive in this order

1. **Merge mindcockpit-ai/cognitive-core#288** (closes mindcockpit-ai/cognitive-core#287). Branch `fix/287-board-reconcile-bulk-query`, single commit `779fef5`. PR replaces the per-issue REST loop in `board-reconcile` with an aliased-GraphQL bulk query (1s vs. 15-min cancellation on the live 112-item board).
   - Confirm CI green: `gh pr checks 288 --repo mindcockpit-ai/cognitive-core`
   - Merge: `gh pr merge 288 --repo mindcockpit-ai/cognitive-core --squash` (per repo convention)
   - The pr-merged automation will move mindcockpit-ai/cognitive-core#287 to To Be Tested. Then run `/project-board verify 287` (acceptance criteria are testable: schedule run completes within step budget, emits `Reconciliation complete:`, no jq parse errors). Then `/project-board approve 287`.
   - **Verification cadence**: schedule cron is `'0 6 * * *'` (08:00 CEST after the project's typical 2-2.5h Actions delay). First post-merge run will be the proof point.

2. **Decide on 3 deferred mindcockpit-ai/cognitive-core#286 followups**:
   - `$GITHUB_STEP_SUMMARY` failure aggregation per-run (observability, P2).
   - `--limit 500` pagination cap audit (silent truncation if board >500 items, P2).
   - Heredoc injection hardening for `${{ github.event.pull_request.body }}` via `env:` indirection (pre-existing on `main`, P2).
   Decide: file separately or close as won't-fix. Architect agent recommended file-as-separate.

3. **Suite 21 snapshot regression** still fails on `main` since mindcockpit-ai/cognitive-core#283/#284 (`validate-bash.sh` changed without baseline regen). File as `chore(tests)` issue, recapture baselines, single-line PR.

## Stale local state to clean up

- `stash@{0}` on `fix/283-cd-aware-branch-guard`: machine-local `cognitive-core.conf` TOFU framework anchor edit (not for commit). Keep stashed or drop.
- `fix/287-board-reconcile-bulk-query` branch will be auto-deleted by GitHub on PR merge if branch protection is configured; otherwise prune locally.
- Remote routine `trig_01XiDZCqhH3wJtjcWzs3WbZM` (claude.ai/code/routines) is `enabled: false, ended_reason: run_once_fired`. Leave for audit trail.

## Backlog priorities (from prior session, still open)

- mindcockpit-ai/cognitive-core#256 (unblocked by mindcockpit-ai/cognitive-core#260): `_cc_validate_framework_source` helper at 9 consumer sites + suite 23.
- mindcockpit-ai/cognitive-core#187: replace magic-string exemption with nonce/state-file (P2, security).
- mindcockpit-ai/cognitive-core#154: orphaned subprocess cleanup (P1, hooks).
- mindcockpit-ai/cognitive-core#210: MCP-Scan integration (P1, security).
- mindcockpit-ai/cognitive-core#141: cognitive-core assistant MVP (Phase 1).
- Test-infra P1 fixes: mindcockpit-ai/cognitive-core#267 (sleep race), mindcockpit-ai/cognitive-core#268 (EXIT-traps + suite 04 silent-pass), mindcockpit-ai/cognitive-core#269 (fake-stat mock).
- Schedule epic mindcockpit-ai/cognitive-core#275 sub-issues (mindcockpit-ai/cognitive-core#270-274) into upcoming sprints.

## Operational reminders

- `PROJECT_PAT` is healthy as of 2026-05-05 19:49Z. Both repo secrets re-set from `pass`. Token-matrix in dev-notes records expiry 2027-05-05.
- Schedule cron fires at 06:00 UTC but consistently delayed 2-2.5h on this org. Don't poll before 08:00Z.
- `gh issue close` triggers the local validate-bash hook closure-guard. To verify any closure-guard scenario read-only, use `gh issue view --json comments` not `gh api repos/.../issues/.../comments` (false-positive on the latter).
- CCR sandbox does NOT ship `gh` CLI. Future scheduled routines must use `curl` + GitHub App installation token.
- Default GitHub Actions `bash` shell adds `-e -o pipefail` automatically but NOT `-u`. Always set `set -euo pipefail` explicitly per `run:` block for CLAUDE.md compliance.
