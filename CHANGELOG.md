# Changelog

## [1.4.1](https://github.com/mindcockpit-ai/cognitive-core/compare/v1.4.0...v1.4.1) (2026-04-01)


### Bug Fixes

* **install:** read version from version.txt instead of parsing install.sh ([d51854b](https://github.com/mindcockpit-ai/cognitive-core/commit/d51854b2ef68a1f38abf09133ffc03f956f9bf3e))

## [1.4.0](https://github.com/mindcockpit-ai/cognitive-core/compare/v1.3.0...v1.4.0) (2026-04-01)


### Features

* **adapters:** add VS Code adapter — Copilot, Continue.dev, Cline ([#81](https://github.com/mindcockpit-ai/cognitive-core/issues/81)) ([b8710db](https://github.com/mindcockpit-ai/cognitive-core/commit/b8710db60641ce2fde9b7429fc73dd189862f343))
* add _cc_rg() ripgrep wrapper with grep fallback ([#134](https://github.com/mindcockpit-ai/cognitive-core/issues/134)) ([bce9056](https://github.com/mindcockpit-ai/cognitive-core/commit/bce905668baa2489bcc0af6fd248c772614912f0))
* **hooks:** add inter-session coordination guard ([#144](https://github.com/mindcockpit-ai/cognitive-core/issues/144)) ([20c8fe6](https://github.com/mindcockpit-ai/cognitive-core/commit/20c8fe6c80655e2e971e5b12624f5622eb4e15cc))
* **hooks:** add session-scoped domain cache for fetch hook ([60670e0](https://github.com/mindcockpit-ai/cognitive-core/commit/60670e080549628c63aa6b4f15e7aad53296a4d9))
* **hooks:** inter-session coordination guard ([#144](https://github.com/mindcockpit-ai/cognitive-core/issues/144)) ([e6a6786](https://github.com/mindcockpit-ai/cognitive-core/commit/e6a6786cf40af6614b57ebae6bb10bda13983ed9))
* **hooks:** notification system for agent completion events ([#158](https://github.com/mindcockpit-ai/cognitive-core/issues/158)) ([5c6342a](https://github.com/mindcockpit-ai/cognitive-core/commit/5c6342af77a749ae28866311f0c4cad3e35cec93))
* **hooks:** register post-fetch-cache in settings template and installer ([9d40e62](https://github.com/mindcockpit-ai/cognitive-core/commit/9d40e629c853d76880d502597d83816a7d611b39))
* **skills:** add codebase grounding to validate-prompt.sh (Layer 2) ([#184](https://github.com/mindcockpit-ai/cognitive-core/issues/184)) ([d5f16d0](https://github.com/mindcockpit-ai/cognitive-core/commit/d5f16d0f416143d040cfe4de9906fe14ed12893a)), closes [#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169)
* **skills:** add validate-prompt.sh — deterministic prompt linter ([#181](https://github.com/mindcockpit-ai/cognitive-core/issues/181)) ([3178c3f](https://github.com/mindcockpit-ai/cognitive-core/commit/3178c3f9fd0c28ae65a0a82115670152e837970d)), closes [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163)
* **skills:** project-board propose — smart implementation prompt generator ([#140](https://github.com/mindcockpit-ai/cognitive-core/issues/140)) ([87b925d](https://github.com/mindcockpit-ai/cognitive-core/commit/87b925db5bfe8e0d37c2b6cfb681e9c724990b51))
* **skills:** project-board propose — smart implementation prompt generator ([#140](https://github.com/mindcockpit-ai/cognitive-core/issues/140)) ([1084485](https://github.com/mindcockpit-ai/cognitive-core/commit/1084485962fc48f787e4476dea61a2694a488690))
* **smoke-test:** ability-type decomposition — reference implementation for [#195](https://github.com/mindcockpit-ai/cognitive-core/issues/195) ([#197](https://github.com/mindcockpit-ai/cognitive-core/issues/197)) ([50fb9c3](https://github.com/mindcockpit-ai/cognitive-core/commit/50fb9c34c0b69576fff95eb20fd4ae901a81749e))


### Bug Fixes

* **adapters:** remove duplicate skill registration in Claude adapter ([f275832](https://github.com/mindcockpit-ai/cognitive-core/commit/f2758323628b89edf6fb26060b324898c89891f7))
* **adapters:** remove duplicate skill registration in Claude adapter ([9577a2e](https://github.com/mindcockpit-ai/cognitive-core/commit/9577a2ec5758e8c3d8d858bdad3e09d0680a1e7c)), closes [#147](https://github.com/mindcockpit-ai/cognitive-core/issues/147)
* **adapters:** resolve merge conflict with main ([ccd141d](https://github.com/mindcockpit-ai/cognitive-core/commit/ccd141d2b6b1bee3d7fbafac4b854ab47fe8cf23))
* **cicd:** migrate board automation to GitHub App token ([#180](https://github.com/mindcockpit-ai/cognitive-core/issues/180)) ([8c42dd4](https://github.com/mindcockpit-ai/cognitive-core/commit/8c42dd48b6d71505e94e2e070e93fee29c875fe7))
* **cicd:** replace heredoc with string concat in closure guard comment ([35b6a21](https://github.com/mindcockpit-ai/cognitive-core/commit/35b6a211f4ae722e0dd238f830aa87000d49d872))
* **ci:** resolve security hook test failures and board automation errors ([1b25b53](https://github.com/mindcockpit-ai/cognitive-core/commit/1b25b531ea787f750811662edb34caca424cfd33))
* **claude-adapter:** create .claude/commands/ stubs for user-invocable skills ([b8952f5](https://github.com/mindcockpit-ai/cognitive-core/commit/b8952f55b6403548496728313cba27bfbee7fb3d)), closes [#146](https://github.com/mindcockpit-ai/cognitive-core/issues/146)
* **claude-adapter:** create .claude/commands/ stubs for user-invocable skills ([36b8a22](https://github.com/mindcockpit-ai/cognitive-core/commit/36b8a22b10807082bd9741fa673792146625df6f)), closes [#146](https://github.com/mindcockpit-ai/cognitive-core/issues/146)
* **hooks:** harden notify-complete against regex injection + ANSI injection ([#193](https://github.com/mindcockpit-ai/cognitive-core/issues/193)) ([7b61a0a](https://github.com/mindcockpit-ai/cognitive-core/commit/7b61a0a9a45b8fbdd04a62aa9422dc89e4731cc4))
* **install:** add security + AI tooling patterns to gitignore template ([#194](https://github.com/mindcockpit-ai/cognitive-core/issues/194)) ([411f78d](https://github.com/mindcockpit-ai/cognitive-core/commit/411f78d798905f7d99f6de522a20538e15474ab0))
* **install:** add session-started, MCP server, gitignore to template ([#185](https://github.com/mindcockpit-ai/cognitive-core/issues/185)) ([67ae1e0](https://github.com/mindcockpit-ai/cognitive-core/commit/67ae1e047578ff0bbef3ea73c7b2d5aa49414969))
* **install:** clean orphaned command stubs during update ([#147](https://github.com/mindcockpit-ai/cognitive-core/issues/147)) ([2035cd2](https://github.com/mindcockpit-ai/cognitive-core/commit/2035cd24dd071b9cb94d23e665f2243007d7f8d6))
* **jira:** convert markdown to proper ADF in issue create and comment ([2364d76](https://github.com/mindcockpit-ai/cognitive-core/commit/2364d765b300ba6544557f56599bd1dacc8d07d3)), closes [#145](https://github.com/mindcockpit-ai/cognitive-core/issues/145)
* **jira:** migrate to /rest/api/3/search/jql endpoint ([#160](https://github.com/mindcockpit-ai/cognitive-core/issues/160)) ([29b5f5a](https://github.com/mindcockpit-ai/cognitive-core/commit/29b5f5a5796c14ad106991e4a057b2e3bd517663)), closes [#150](https://github.com/mindcockpit-ai/cognitive-core/issues/150)
* **jira:** wiki markup to ADF, status map lookups, hook hardening ([#198](https://github.com/mindcockpit-ai/cognitive-core/issues/198), [#206](https://github.com/mindcockpit-ai/cognitive-core/issues/206)) ([#211](https://github.com/mindcockpit-ai/cognitive-core/issues/211)) ([75ab524](https://github.com/mindcockpit-ai/cognitive-core/commit/75ab5245bf0979c957adb5d88483472a52ad1953))
* **plugin,docs:** sync missing hooks + agent health docs ([#164](https://github.com/mindcockpit-ai/cognitive-core/issues/164), [#165](https://github.com/mindcockpit-ai/cognitive-core/issues/165)) ([#179](https://github.com/mindcockpit-ai/cognitive-core/issues/179)) ([26167be](https://github.com/mindcockpit-ai/cognitive-core/commit/26167be05ea301e3f1f63892967888f8abf58f30))
* **security:** closure guard review fixes — uppercase X, audit log, test gaps ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#186](https://github.com/mindcockpit-ai/cognitive-core/issues/186)) ([5f23cc0](https://github.com/mindcockpit-ai/cognitive-core/commit/5f23cc0ed459e1e3265bf2922476f82ef4cb11a8))
* **security:** deterministic closure guard for pb_issue_close ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#183](https://github.com/mindcockpit-ai/cognitive-core/issues/183)) ([ea31144](https://github.com/mindcockpit-ai/cognitive-core/commit/ea311444db6af62b79e2a5d8b3ee6e8db01ea015))
* **skills:** provider browse URLs + security hardening ([#161](https://github.com/mindcockpit-ai/cognitive-core/issues/161)) ([#166](https://github.com/mindcockpit-ai/cognitive-core/issues/166)) ([b950559](https://github.com/mindcockpit-ai/cognitive-core/commit/b950559cb403cc9196dc209645c861c573f5bb1d))
* **skills:** resolve code review findings — POSIX regex, provider consistency ([08b2cde](https://github.com/mindcockpit-ai/cognitive-core/commit/08b2cdeee16cb26ff9cd60b18c11bb615571ffe2))
* **skills:** resolve propose verification gaps — recipe ref, provider support, business mode ([764f6cd](https://github.com/mindcockpit-ai/cognitive-core/commit/764f6cdbe2ff59add288def4e5c7b7794ed4fb17))
* **tests:** clean Section 32 grep pipeline ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#191](https://github.com/mindcockpit-ai/cognitive-core/issues/191)) ([d5a83f5](https://github.com/mindcockpit-ai/cognitive-core/commit/d5a83f5094df8514ec5bcc5a1bc4dedd05d29e60))
* **tests:** replace vacuous ADF assertion with real exit-code check ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#190](https://github.com/mindcockpit-ai/cognitive-core/issues/190)) ([35ced3f](https://github.com/mindcockpit-ai/cognitive-core/commit/35ced3f71430cac05851d7067662379bf882fc33))

## [1.3.0](https://github.com/mindcockpit-ai/cognitive-core/compare/v1.2.0...v1.3.0) (2026-03-28)


### Features

* **adapters:** add VS Code adapter — Copilot, Continue.dev, Cline ([#81](https://github.com/mindcockpit-ai/cognitive-core/issues/81)) ([b8710db](https://github.com/mindcockpit-ai/cognitive-core/commit/b8710db60641ce2fde9b7429fc73dd189862f343))
* add _cc_rg() ripgrep wrapper with grep fallback ([#134](https://github.com/mindcockpit-ai/cognitive-core/issues/134)) ([bce9056](https://github.com/mindcockpit-ai/cognitive-core/commit/bce905668baa2489bcc0af6fd248c772614912f0))
* **agents:** background agent timeout and health monitoring ([#74](https://github.com/mindcockpit-ai/cognitive-core/issues/74)) ([db33cce](https://github.com/mindcockpit-ai/cognitive-core/commit/db33cce13c741053e4f02d62e6f51d51795d3ad2))
* **hooks:** add inter-session coordination guard ([#144](https://github.com/mindcockpit-ai/cognitive-core/issues/144)) ([20c8fe6](https://github.com/mindcockpit-ai/cognitive-core/commit/20c8fe6c80655e2e971e5b12624f5622eb4e15cc))
* **hooks:** add session-scoped domain cache for fetch hook ([60670e0](https://github.com/mindcockpit-ai/cognitive-core/commit/60670e080549628c63aa6b4f15e7aad53296a4d9))
* **hooks:** inter-session coordination guard ([#144](https://github.com/mindcockpit-ai/cognitive-core/issues/144)) ([e6a6786](https://github.com/mindcockpit-ai/cognitive-core/commit/e6a6786cf40af6614b57ebae6bb10bda13983ed9))
* **hooks:** notification system for agent completion events ([#158](https://github.com/mindcockpit-ai/cognitive-core/issues/158)) ([5c6342a](https://github.com/mindcockpit-ai/cognitive-core/commit/5c6342af77a749ae28866311f0c4cad3e35cec93))
* **hooks:** register post-fetch-cache in settings template and installer ([9d40e62](https://github.com/mindcockpit-ai/cognitive-core/commit/9d40e629c853d76880d502597d83816a7d611b39))
* **skills:** add codebase grounding to validate-prompt.sh (Layer 2) ([#184](https://github.com/mindcockpit-ai/cognitive-core/issues/184)) ([d5f16d0](https://github.com/mindcockpit-ai/cognitive-core/commit/d5f16d0f416143d040cfe4de9906fe14ed12893a)), closes [#169](https://github.com/mindcockpit-ai/cognitive-core/issues/169)
* **skills:** add validate-prompt.sh — deterministic prompt linter ([#181](https://github.com/mindcockpit-ai/cognitive-core/issues/181)) ([3178c3f](https://github.com/mindcockpit-ai/cognitive-core/commit/3178c3f9fd0c28ae65a0a82115670152e837970d)), closes [#163](https://github.com/mindcockpit-ai/cognitive-core/issues/163)
* **skills:** project-board propose — smart implementation prompt generator ([#140](https://github.com/mindcockpit-ai/cognitive-core/issues/140)) ([87b925d](https://github.com/mindcockpit-ai/cognitive-core/commit/87b925db5bfe8e0d37c2b6cfb681e9c724990b51))
* **skills:** project-board propose — smart implementation prompt generator ([#140](https://github.com/mindcockpit-ai/cognitive-core/issues/140)) ([1084485](https://github.com/mindcockpit-ai/cognitive-core/commit/1084485962fc48f787e4476dea61a2694a488690))


### Bug Fixes

* **adapters:** remove duplicate skill registration in Claude adapter ([f275832](https://github.com/mindcockpit-ai/cognitive-core/commit/f2758323628b89edf6fb26060b324898c89891f7))
* **adapters:** remove duplicate skill registration in Claude adapter ([9577a2e](https://github.com/mindcockpit-ai/cognitive-core/commit/9577a2ec5758e8c3d8d858bdad3e09d0680a1e7c)), closes [#147](https://github.com/mindcockpit-ai/cognitive-core/issues/147)
* **adapters:** resolve merge conflict with main ([ccd141d](https://github.com/mindcockpit-ai/cognitive-core/commit/ccd141d2b6b1bee3d7fbafac4b854ab47fe8cf23))
* **cicd:** migrate board automation to GitHub App token ([#180](https://github.com/mindcockpit-ai/cognitive-core/issues/180)) ([8c42dd4](https://github.com/mindcockpit-ai/cognitive-core/commit/8c42dd48b6d71505e94e2e070e93fee29c875fe7))
* **cicd:** replace heredoc with string concat in closure guard comment ([35b6a21](https://github.com/mindcockpit-ai/cognitive-core/commit/35b6a211f4ae722e0dd238f830aa87000d49d872))
* **ci:** resolve security hook test failures and board automation errors ([1b25b53](https://github.com/mindcockpit-ai/cognitive-core/commit/1b25b531ea787f750811662edb34caca424cfd33))
* **claude-adapter:** create .claude/commands/ stubs for user-invocable skills ([b8952f5](https://github.com/mindcockpit-ai/cognitive-core/commit/b8952f55b6403548496728313cba27bfbee7fb3d)), closes [#146](https://github.com/mindcockpit-ai/cognitive-core/issues/146)
* **claude-adapter:** create .claude/commands/ stubs for user-invocable skills ([36b8a22](https://github.com/mindcockpit-ai/cognitive-core/commit/36b8a22b10807082bd9741fa673792146625df6f)), closes [#146](https://github.com/mindcockpit-ai/cognitive-core/issues/146)
* **install:** clean orphaned command stubs during update ([#147](https://github.com/mindcockpit-ai/cognitive-core/issues/147)) ([2035cd2](https://github.com/mindcockpit-ai/cognitive-core/commit/2035cd24dd071b9cb94d23e665f2243007d7f8d6))
* **jira:** convert markdown to proper ADF in issue create and comment ([2364d76](https://github.com/mindcockpit-ai/cognitive-core/commit/2364d765b300ba6544557f56599bd1dacc8d07d3)), closes [#145](https://github.com/mindcockpit-ai/cognitive-core/issues/145)
* **jira:** migrate to /rest/api/3/search/jql endpoint ([#160](https://github.com/mindcockpit-ai/cognitive-core/issues/160)) ([29b5f5a](https://github.com/mindcockpit-ai/cognitive-core/commit/29b5f5a5796c14ad106991e4a057b2e3bd517663)), closes [#150](https://github.com/mindcockpit-ai/cognitive-core/issues/150)
* **plugin,docs:** sync missing hooks + agent health docs ([#164](https://github.com/mindcockpit-ai/cognitive-core/issues/164), [#165](https://github.com/mindcockpit-ai/cognitive-core/issues/165)) ([#179](https://github.com/mindcockpit-ai/cognitive-core/issues/179)) ([26167be](https://github.com/mindcockpit-ai/cognitive-core/commit/26167be05ea301e3f1f63892967888f8abf58f30))
* **security:** closure guard review fixes — uppercase X, audit log, test gaps ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#186](https://github.com/mindcockpit-ai/cognitive-core/issues/186)) ([5f23cc0](https://github.com/mindcockpit-ai/cognitive-core/commit/5f23cc0ed459e1e3265bf2922476f82ef4cb11a8))
* **security:** deterministic closure guard for pb_issue_close ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#183](https://github.com/mindcockpit-ai/cognitive-core/issues/183)) ([ea31144](https://github.com/mindcockpit-ai/cognitive-core/commit/ea311444db6af62b79e2a5d8b3ee6e8db01ea015))
* **skills:** provider browse URLs + security hardening ([#161](https://github.com/mindcockpit-ai/cognitive-core/issues/161)) ([#166](https://github.com/mindcockpit-ai/cognitive-core/issues/166)) ([b950559](https://github.com/mindcockpit-ai/cognitive-core/commit/b950559cb403cc9196dc209645c861c573f5bb1d))
* **skills:** resolve code review findings — POSIX regex, provider consistency ([08b2cde](https://github.com/mindcockpit-ai/cognitive-core/commit/08b2cdeee16cb26ff9cd60b18c11bb615571ffe2))
* **skills:** resolve propose verification gaps — recipe ref, provider support, business mode ([764f6cd](https://github.com/mindcockpit-ai/cognitive-core/commit/764f6cdbe2ff59add288def4e5c7b7794ed4fb17))
* **tests:** clean Section 32 grep pipeline ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#191](https://github.com/mindcockpit-ai/cognitive-core/issues/191)) ([d5a83f5](https://github.com/mindcockpit-ai/cognitive-core/commit/d5a83f5094df8514ec5bcc5a1bc4dedd05d29e60))
* **tests:** replace vacuous ADF assertion with real exit-code check ([#182](https://github.com/mindcockpit-ai/cognitive-core/issues/182)) ([#190](https://github.com/mindcockpit-ai/cognitive-core/issues/190)) ([35ced3f](https://github.com/mindcockpit-ai/cognitive-core/commit/35ced3f71430cac05851d7067662379bf882fc33))
* **tests:** resolve ShellCheck warnings in suite 15 — unused vars, redirect order ([8d2e0e5](https://github.com/mindcockpit-ai/cognitive-core/commit/8d2e0e56a0f9e3ee5e92c2ab9fb8df007ff7264d))

## [1.2.0](https://github.com/mindcockpit-ai/cognitive-core/compare/v1.1.0...v1.2.0) (2026-03-23)

### Features

* **install:** gitignore policy — base template (16 IDEs, 3 OS families, IaC secrets) + 11 language-pack fragments, auto-merged on install/update ([docs](docs/GITIGNORE_POLICY.md))
* **install:** add struts-jsp to language menu with lint/test case branch
* **tests:** add test suite 15-gitignore-policy.sh (138 assertions across 8 test categories)
* **tests:** total assertions now 809 across 16 suites (up from 528 across 13)

### Bug Fixes

* **install:** fix unbound variable in merge_gitignore_rules when 3rd parameter omitted
* **install:** fix duplicate section headers on incremental update re-runs
* **rust:** comment out Cargo.lock (commit for binaries, ignore for libraries per official guidance)
* **csharp:** remove Visual Studio/Rider pattern duplicates already covered by base template

## [1.1.0](https://github.com/mindcockpit-ai/cognitive-core/compare/v1.0.0...v1.1.0) (2026-03-18)


### Features

* **adapters:** expose shared MCP server for Claude Code ([#88](https://github.com/mindcockpit-ai/cognitive-core/issues/88)) ([23cbabb](https://github.com/mindcockpit-ai/cognitive-core/commit/23cbabb7c53c0cb8135cf46803107630c059a9b0))
* **agents:** formalize information provenance with W3C PROV vocabulary ([#89](https://github.com/mindcockpit-ai/cognitive-core/issues/89)) ([af6d98c](https://github.com/mindcockpit-ai/cognitive-core/commit/af6d98ca680bcb03fa145ff1676b6456575f81c6))
* **agents:** formalize session lifecycle with A2A-inspired state machine ([#90](https://github.com/mindcockpit-ai/cognitive-core/issues/90)) ([724be7f](https://github.com/mindcockpit-ai/cognitive-core/commit/724be7f00429fb995112403443ac35a5b702571e))
* **skills:** add batch-review skill with 3-tier processing strategy ([#87](https://github.com/mindcockpit-ai/cognitive-core/issues/87)) ([c4c10f2](https://github.com/mindcockpit-ai/cognitive-core/commit/c4c10f2e9dbe6614a832c2eecbb5c66c82710926))


### Bug Fixes

* **presentations:** apply code review fact-check corrections ([aefe572](https://github.com/mindcockpit-ai/cognitive-core/commit/aefe57203db3feec350f8a98a2e572036ac2fefe))
* **presentations:** correct skill count 46→47 (batch-review added 20th core skill) ([9d76f46](https://github.com/mindcockpit-ai/cognitive-core/commit/9d76f467cf6d0bd7d69bc5e46f54faae746d84fb))

## [1.0.0](https://github.com/mindcockpit-ai/cognitive-core/compare/v0.2.0...v1.0.0) (2026-03-18)

cognitive-core reaches v1.0.0 with 4 industry-first features, enterprise governance,
multi-adapter support, and 46 composable skills.

### Features

* **agents:** add source authority model to filter AI slop and hallucinations (0558925)
* **agents:** add team-aware estimation and research-first principle (4e3ee40)
* **skills:** enterprise board features — blocked, WIP limits, SOX approval, metrics (4f7b36e)
* **skills:** add epic decomposition, recursive verification, and PM recipes (ae3fbf1)
* **tests:** count rules, adapters, and total skills in health JSON (8d853cd)
* **cicd:** add AI moderator and welcome workflows (e6fa311)
* **#71:** add session hygiene — glymphatic cleanup for stale processes (2c3550d)
* **cicd:** install project-board-automation workflow with real project IDs (a40875c)
* **skills:** add human approval gate to project-board workflow (d7d09cd)
* **skills:** add provider abstraction to project-board and fix auto-onboard (9e9e2ad)
* **#59-#70:** certification alignment and Dennis feedback fixes (ee30925)
* **#63:** add Parsimony Principle as explicit design guideline (829d8dc)
* **packs:** add Struts + JSP language pack for legacy Java web archeology (d244584)
* **plugin:** repackage cognitive-core as Claude Code native plugin (3f16050)
* **packs:** add Spring Boot language pack with version-aware skills (v2-v4) (38a9282)
* **packs:** add Angular language pack (v18-21), fix Oracle pack, update docs (96bd4ac)
* **react,core:** add E2E testing patterns from production PoC (40754f0)
* **cicd:** add GitHub App reviewer setup guide and token utility (bd173d6)
* **adapters:** add platform adapter system with Claude + Aider support (a6c3592)
* **cicd:** add branching workflow, release notes, and PR templates (5f75d5b)
* **skills:** add Closure Guard to prevent premature issue closure (f912f14)
* **skills:** add auto-branch creation to project-board move command (cb40a43)
* **acceptance-verification:** auto-tick checkboxes on verification PASS (6ffced6)
* **project-board:** allow reopen from Done/Canceled with auto gh issue reopen (52dd568)
* **project-board:** add plan attachment, auto-sprint, and auto-assignee to move command (fbe6fa6)
* **project-board:** add cross-project contamination guard (4ad276c)
* **smoke-test:** add happy path smoke testing skill (cf1ac89)
* **lint-debt:** add lint suppression tracking skill and hook enhancement (1e93338)
* **language-packs:** add messaging skills to all language packs (e6aabd6)
* **python:** add messaging middleware patterns skill (d071967)
* **python:** modernize language pack to 3.12+ with DDD, Pydantic v2, SQLAlchemy 2.0 (5ffef4e)
* **catalog:** add collect_catalog() and catalog_description frontmatter (b7dcca3)
* **secrets:** add secrets-run/secrets-store utilities with Keychain backend (2a64357)
* add --json test output, secrets-setup skill, and website auto-update pipeline (9e1b8e7)
* **skills:** add workspace-monitor skill for runtime log and build observability (3d45184)
* **skills:** add Canceled column, transition rules, and CI workflows (c9e2a91)
* **skills:** backport TIMS project-board improvements (a8c16dd)
* add skill-updater agent and skill-sync skill (ca934d3)

### Bug Fixes

* **cicd:** respect human approval gate in PR merge and issue close automation (9197dfe)
* **cicd:** make website update workflow resilient to missing PAT (3074d27)
* **#58:** CRLF line endings break installer on Windows Git Bash (aae9dae)
* **install:** plugin-aware coexistence instead of deprecation (0d2fe02)
* correct copyright holder name in LICENSE and NOTICE (f1f894b)
* **docs:** correct skill count to 43 (19 core + 24 language/database pack) (95f8242)
* **#36:** fitness-checks.sh fails on large codebases (cbc2210)
* remove unused legacy color aliases for ShellCheck (e57992d)
* use CLAUDE_PROJECT_DIR to isolate security hook tests from repo config (ed056a9)
* resolve pre-existing CI failures (f742493)
* exclude docs/examples/tests from security scan false positives (e19a37b)
* **tests:** resolve SIGPIPE false-positive in frontmatter validation (57d60f2)
* **tests:** resolve shellcheck SC2034 warnings for unused variables (6dbfd02)
* auto-add security.log to .gitignore during install and update (56e9615)

### Documentation

* add board workflow governance research paper (a5ee6f6)
* add detailed research papers for 4 novel features (f8e7abc)
* add landing page screenshot to README (dc100c3)
* add landing page screenshot for README (995cc7e)
* issue #76 deployment verification screenshot (79664a2)
* add email templates (DE/SK, formal/informal) and strategic README sections (d42140e)
* complete recipes section — 10 step-by-step guides for beginners (9176992)
* issue #76 deployment verification screenshot (3b06ab7)
* issue #76 deployment verification screenshot (9aca74e)
* add screenshot evidence workflow for issue verification (6aa685b)
* add coordinator autonomous workflow recipe (48c09b2)
* add Phase 1 recipes for Wednesday presentation (910c1bb)
* add legacy enterprise stacks analysis for software archeology (96bf2f8)
* add Community section with GitHub Discussions link (14e2e1c)
* add brand guidelines extracted from multivac42.ai (2e710c7)
* reference Agent Learning Framework RFC in roadmap (#32) (dd242ac)
* add headless browser implementation guide (9ecd03d)
* update documentation to reflect current feature inventory (2c330c5)
* add Framework Health screenshot to README (d7473af)

### Highlights

* **Source Authority Model (T1-T5)** — 5-tier research quality classification, AI slop filtering
* **Team-Aware Estimation** — human+AI critical path, no more fictional developer-days
* **Graduated Fitness Gates** — quality thresholds 60% → 95% across the pipeline
* **Recursive Epic Verification** — criteria-level verification with evidence gathering
* **SOX-Compliant Board Workflow** — approval gate, WIP limits, different-approver enforcement
* **Multi-Adapter** — Claude Code, Aider+Ollama, IntelliJ+DevoxxGenie (VS Code, Eclipse planned)
* **46 Skills** — 19 core + 26 language-pack + 1 database-pack
* **10 Specialist Agents** — hub-and-spoke coordination with smart delegation
* **13 Test Suites, 525+ Tests** — all passing
