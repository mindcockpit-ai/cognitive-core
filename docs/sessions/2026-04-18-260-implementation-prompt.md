Implement mindcockpit-ai/cognitive-core#260: CC_FRAMEWORK_ROOT at install + TOFU migration + conf hardening.

<scope>
1. install.sh: inside CONF_FILE heredoc (line 267), add `# ===== FRAMEWORK ANCHOR =====` section BEFORE PROJECT IDENTITY, with `CC_FRAMEWORK_ROOT="$(realpath "${SCRIPT_DIR}" 2>/dev/null || (cd "${SCRIPT_DIR}" && pwd))"`. After heredoc closes: chmod 0644 → write → chmod 0444. For `--force`, chmod 0644 before rewrite.
2. install.sh: verify conf owner uid = `id -u` via stat -f %u → stat -c %u → `ls -ldn | awk '{print $3}'`. Mismatch exits non-zero. Honor `CC_CONF_OWNER_SKIP=1` → `_cc_security_log WARN owner-check-skipped`.
3. core/hooks/setup-env.sh: inline migration after `_cc_load_config` (no helper — single call site). Atomic lock via `mkdir .claude/cognitive-core/anchor.lock.d 2>/dev/null` (session-guard.sh pattern). Detect absence with `grep -qE '^CC_FRAMEWORK_ROOT='`. If absent: read this project's version.json.source, resolve, chmod 0644, append once, chmod 0444, `_cc_security_log WARN tofu-migration`, release lock. Trap-cleanup lockdir.
4. tests/suites/24-framework-root-anchor.sh: ≥20 assertions. Cover install value; 0444 mode; owner matches id -u; TOFU pins once; idempotency (md5 stable + single-line); no overwrite on differing value; owner mismatch fails install (shadow-PATH stat mock per suite 22; _skip if unavailable); update.sh sources 0444 cleanly. Seed test_dir with minimal conf (suite 04 pattern) before install. Source _lib.sh directly for TOFU tests.
5. tests/run-all.sh: add suite 24 pretty-name.
</scope>

<constraints>
- POSIX ERE. No python3. Migration inlined (Parsimony).
- Commit scope ∈ {install, hooks, security}.
- Do NOT introduce any $SOURCE validator — that is mindcockpit-ai/cognitive-core#256.
- Do NOT change version.json consumers. update.sh must NOT read or write CC_FRAMEWORK_ROOT.
- Do NOT require root or sudo.
- Do NOT overwrite a differing existing CC_FRAMEWORK_ROOT — reject.
- Do NOT add concurrent-race test — lock-early-bail suffices.
</constraints>

<agents>
- @security-analyst: TOFU, lock race, permission model
- @code-standards-reviewer: Parsimony, heredoc, stat portability
- @test-specialist: suite 24 matrix, shadow-PATH mock
- @solution-architect: per-project pinning, update.sh boundary, rollback
</agents>

<acceptance_criteria>
- [ ] `install.sh` writes `CC_FRAMEWORK_ROOT=<resolved SCRIPT_DIR>` into `cognitive-core.conf` on every fresh install
- [ ] Resolved path uses `realpath` with `cd+pwd` fallback — no python3 dependency
- [ ] TOFU migration pins `CC_FRAMEWORK_ROOT` from `version.json.source` once on first post-upgrade run
- [ ] Migration is idempotent — second upgrade does not overwrite
- [ ] `cognitive-core.conf` has mode 0444 and owner = current user after install
- [ ] Install fails cleanly with clear error if owner check fails
- [ ] Migration event logged to `.claude/cognitive-core/security.log` via `_cc_security_log WARN`
- [ ] Regression test covers fresh install, TOFU migration, idempotency, conf permissions
- [ ] All existing test suites pass
- [ ] `update.sh` sources the 0444 conf cleanly (read permission preserved)
- [ ] `install.sh --force` re-runs successfully against a 0444 conf
- [ ] Older pre-#260 versions that source `cognitive-core.conf` ignore the new line (rollback safety)
</acceptance_criteria>

<context>
- install.sh:16 (SCRIPT_DIR); install.sh:267–341 (CONF_FILE heredoc)
- core/hooks/_lib.sh:16 (_cc_load_config); :216 (_cc_security_log)
- Atomic lock precedent: core/hooks/session-guard.sh (mkdir-based)
- Edit targets: install.sh; core/hooks/setup-env.sh; tests/suites/24-*.sh; tests/run-all.sh
- Blocks mindcockpit-ai/cognitive-core#256; parent mindcockpit-ai/cognitive-core#255 (merged via #259)
- Threat class: trust-on-first-use — not filesystem-compromise-proof
</context>

<after_implementation>
- `bash tests/run-all.sh` passes (suite 24 ≥20 assertions); `bash -n` clean.
- Fresh install: 0444 conf with CC_FRAMEWORK_ROOT in FRAMEWORK ANCHOR section.
- Pre-upgrade synthetic project: pins once, idempotent on second run, md5 stable.
- Owner-mismatch: exits non-zero; CC_CONF_OWNER_SKIP=1 downgrades to WARN.
- `install.sh --force` and `update.sh` both handle the 0444 conf.
- mindcockpit-ai/cognitive-core#256 scope untouched.
- Commit `feat(install): capture CC_FRAMEWORK_ROOT + TOFU migration + conf hardening`; body `Closes mindcockpit-ai/cognitive-core#260`. Push, open PR.
</after_implementation>
