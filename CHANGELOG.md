# Changelog

## [Unreleased]

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
