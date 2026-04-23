# Continuation prompt — fresh session resume

Self-contained brief for a fresh session. Paste as the first user message after `/session-resume`.

---

Read `docs/sessions/2026-04-21-session.md` first for full context. Summary: PR mindcockpit-ai/cognitive-core#276 is open and mergeable, fixes mindcockpit-ai/cognitive-core#265 (manifest-regen empty-files bug + adapter impact + macOS iconv linter bug). All 24 test suites pass on the branch. Working tree has 5 uncommitted `.claude/hooks/*.sh` files that are framework-source syncs from the prior session.

Order of business:

1. **Check mindcockpit-ai/cognitive-core#276 status.** If CI is green and it's still open, merge it (squash, default commit message). If CI is red, investigate before merging.

2. **Verify CI automation moved mindcockpit-ai/cognitive-core#265 → To Be Tested** after the merge. If it did, run `/project-board approve 265` to move it to Done. If automation didn't fire, debug `cicd/workflows/project-board-automation.yml` against the merged PR's body (we replaced `Closes #265` with `Refs #265` to preserve the approval gate — confirm the workflow's regex still matches `Refs`).

3. **Decide on the 5 stale hook WIP.** `git status` will show modifications to `_session-hygiene.sh`, `post-edit-lint.sh`, `session-guard.sh`, `setup-env.sh`, `validate-bash.sh` — these are framework-source syncs from the session-start hook drift discovery. Now that mindcockpit-ai/cognitive-core#276 is merged and the manifest regenerates correctly, options:
   - **Commit as `chore(hooks): sync installed hooks with framework source`** — explicit historical record.
   - **Revert and let `update.sh` re-sync from the now-correct manifest** — cleaner, lets the fixed tooling do its job.
   Pick whichever, then proceed.

4. **Pick next priority.** All blocked items are now unblocked. Options:
   - **mindcockpit-ai/cognitive-core#256** — `_cc_validate_framework_source` helper at 9 consumer sites + suite 23. This was the original session-resume continuation before mindcockpit-ai/cognitive-core#265 surfaced.
   - **mindcockpit-ai/cognitive-core#267/268/269** — three P1 test-infra bugs. Small/medium, can parallelize via project-coordinator delegation.
   - **mindcockpit-ai/cognitive-core#275 epic** — schedule its 5 sub-issues into upcoming sprints.

   Recommendation: ask user which they want. mindcockpit-ai/cognitive-core#256 is the longest-deferred; the P1 test-infra issues are the highest-leverage (suite 04 silent-pass is masking real install failures right now in CI).

Do NOT start coding before clarifying the choice in step 4. Confirm with the user first. The board approval flow (steps 1-2) can proceed without confirmation since they were planned at the end of the prior session.

Conventions to remember (already in CLAUDE.md but reinforce on cold start):
- Always reference issues/PRs as `mindcockpit-ai/cognitive-core#N` clickable form.
- Never bypass the board approval gate — `/project-board approve` is the only path from To Be Tested → Done.
- Never amend commits; always create new ones (CLAUDE.md rule, enforced by hooks).
- POSIX ERE only in shell (no `\s`, `\b`, `\w`) for macOS+Linux compatibility.
