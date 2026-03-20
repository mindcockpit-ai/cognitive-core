# Professional Java Development: SE Tools & AI-Assisted Engineering

## Course Plan — Summer Semester 2026

**Institution:** Hochschule Albstadt-Sigmaringen, Fakultät Informatik
**Instructors:** Dennis Piskovatskov (Privatdozent), Prof. German Nemirovski
**Students:** BSc, Semester 3–6
**Total:** 30 hours across 5 sessions
**Final Deliverable:** Practical project (Weather App) using SE tools + cognitive-core framework

---

## Philosophy

> "Anybody can vibe-code. We build the Grundgerüst: tools first, then LLM, then framework."

1. **Session 1 is pure engineering** — no LLM, no AI. Students must understand what tools do before any automation.
2. **cognitive-core enters progressively** — hooks in Session 2, skills in Session 3, agents + full architecture in Session 4.
3. **Old content stays** — Maven, Git, CheckStyle/PMD/SpotBugs, JUnit/Mockito, Jenkins. Every topic from the 2024 script is covered.
4. **LLM is a professional tool, not a crutch** — students learn to direct, verify, and constrain AI output.

---

## Schedule Overview

| Session | Date       | Hours | Focus                                          | cognitive-core |
|---------|------------|-------|-------------------------------------------------|----------------|
| 1       | 2026-03-21 | 6h    | Build Processes: Apache Ant → Maven             | —              |
| 2       | 2026-04-11 | 8h    | Git + Code Quality + Claude Code + Hooks        | Hooks          |
| 3       | 2026-04-25 | 4h    | JUnit/Mockito + Quality Skills                  | Skills         |
| 4       | 2026-05-16 | 8h    | CI/CD + MCP + Agentic Architecture              | Agents         |
| 5       | 2026-06-27 | 4h    | Final Project Presentation + Review             | Full Framework |

---

## Session 1 — March 21 (6 hours): Build Processes

**No LLM. No AI. Pure software engineering.**

### Block 1.1 — Why Build Processes Exist (1.5h) — Theory + Demo

- The problem: manual compilation, dependency management, reproducibility
- Evolution: `javac` by hand → Ant (imperative) → Maven (declarative)
- Apache Ant deep enough to understand the paradigm:
  - `build.xml`, targets, tasks, dependencies between targets
  - `<javac>`, `<jar>`, `<copy>`, `<delete>`
  - Properties and path references
- **Key takeaway:** Ant makes you specify EVERYTHING. Maven assumes conventions.
  This same pattern repeats with LLMs later: you must know what is being automated.

### Block 1.2 — Apache Maven: Fundamentals (1.5h) — Theory

- Convention over Configuration
- The Project Object Model (POM)
- Installing Maven, settings.xml
- Coordinates: groupId, artifactId, version
- Dependency resolution and repositories

### Block 1.3 — Apache Maven: Build Lifecycle & Advanced (1.5h) — Theory

- Build lifecycle phases: validate → compile → test → package → verify → install → deploy
- Build profiles (dev, test, prod)
- Maven configuration and plugins
- Assemblies, resource filtering
- Site generation, dependency tree

### Block 1.4 — Praxis: Maven Project (1.5h) — Hands-on

- Create a multi-module Maven project from scratch (jar + pom)
- Configure 2 build profiles
- Add dependencies (commons-lang3, Log4j2)
- Run full lifecycle: `mvn clean install`
- Generate site, inspect dependency tree
- Set up project structure for the Weather App that will be used all semester

**Deliverable:** Working Maven multi-module Weather App skeleton with proper directory structure.

---

## Session 2 — April 11 (8 hours): Git + Code Quality + LLM Introduction

### Block 2.1 — Git Fundamentals (2h) — Theory + Praxis

- SVN vs Git (decentralized concept)
- Installation, first steps with console
- Branching, merging (manual + GUI)
- Working with remotes (clone, fetch, push, pull)
- Revert, rebase
- Aliases, `.gitignore` hygiene
- Conventional commits: `type: subject`
- **Praxis:** Create repo, clone, branch, merge conflicts, push to GitHub

### Block 2.2 — Code Quality: CheckStyle, PMD, SpotBugs (2h) — Theory + Praxis

- Why code quality tools exist (not just style — bugs, security, maintainability)
- CheckStyle: `google_checks.xml`, Maven plugin, rules
- PMD: `pmd-custom-ruleset.xml`, Maven plugin, rules
- SpotBugs (replaces FindBugs): Maven plugin, bug patterns
- Code formatting: Google Java Style Guide, Eclipse/IntelliJ config
- **Praxis:** Run all 3 tools on the Weather App. Fix violations manually.

### Block 2.3 — Enter the LLM: What Changed and Why (1h) — Theory

- What is an LLM? (brief, practical — not ML theory)
- The "vibe coding" phenomenon (Karpathy, Feb 2025):
  - Definition: accepting AI suggestions without understanding
  - Quantified risks (CodeRabbit Dec 2025): 1.7× more defects, 2.74× security issues, 8× performance problems
- **The course position:** LLM is a professional tool. Vibe coding is not professional development.
- Overview: Claude Code, Claude API, MCP, Agent SDK (what exists, where we're going)

### Block 2.4 — Claude Code + cognitive-core Hooks (3h) — Theory + Praxis

- **Claude Code Setup (1h):**
  - Installation, first session
  - Built-in tools: Read, Write, Edit, Bash, Grep, Glob
  - CLAUDE.md: project-level configuration
  - `.claude/rules/` with YAML frontmatter path-scoping

- **cognitive-core Introduction (30min):**
  - What is cognitive-core? Quality enforcer, not code generator.
  - Architecture overview: hooks → skills → agents (progressive complexity)
  - The Human Approval Gate principle: AI suggests, humans approve
  - Student Lab Pack: minimal config for the course

- **cognitive-core Hooks — Passive Quality Feedback (1.5h):**
  - Install cognitive-core with Student Lab Pack config (pre-configured by instructor)
  - `post-edit-lint.sh`: auto-lint on every file edit
    - `CC_LINT_COMMAND="mvn checkstyle:check pmd:check"`
    - Students write Java code → immediate CheckStyle/PMD feedback
  - `validate-bash.sh`: blocks destructive commands (`git push --force`, `rm -rf .git`)
  - `setup-env.sh`: session initialization
  - `compact-reminder.sh`: rules survive long sessions
  - **Praxis:** Write code in Claude Code with hooks active. Experience:
    - Automatic lint feedback after every edit
    - Blocked dangerous git operations
    - Compare: manual `mvn checkstyle:check` vs automatic hook feedback

**Deliverable:** Weather App on GitHub with clean Git history. CheckStyle/PMD/SpotBugs passing. Claude Code configured. cognitive-core hooks active.

---

## Session 3 — April 25 (4 hours): Testing + cognitive-core Skills

### Block 3.1 — JUnit 5 + Mockito (2h) — Theory + Praxis

- JUnit 5: lifecycle (@BeforeAll, @BeforeEach, @AfterAll, @AfterEach)
- Annotations: @Test, @DisplayName, @ParameterizedTest, @Nested
- Assertions: assertEquals, assertTrue, assertThrows
- Mockito: mocking framework, @Mock, @InjectMocks, when/thenReturn, verify
- Test suites
- **Praxis:** Write minimum 5 tests manually for the Weather App. Use Mockito for service layer.

### Block 3.2 — cognitive-core Skills: Active Quality Checks (2h) — Theory + Praxis

- **New commands students learn:**
  - `/pre-commit` — structured quality report before committing
    - Which files pass/fail, specific violations
    - Fix violations → commit only after clean pre-commit
  - `/fitness` — multi-dimensional quality scoring
    - 4 dimensions: standards, architecture, tests, security
    - Fitness gates: lint 70%, commit 80%, test 85%, merge 90%
    - "Your code compiles. But is it good? Fitness score 72% means 28% fails."
  - `/code-review` — structured review against conventions
    - Findings with severities (ERROR, WARN, INFO)
    - Architectural checks: "Why is database code in the controller?"
  - `/test-scaffold` — JUnit 5 test scaffolding
    - **Critical lesson:** Compare AI-scaffolded tests vs manually written tests
    - AI tests often look correct but test nothing meaningful
    - Students evaluate: coverage, assertion quality, edge cases

- **Praxis:**
  - Run `/pre-commit` before every commit — iterate until clean
  - Run `/fitness` — try to reach 90%
  - Run `/code-review` on each other's Weather App code
  - Use `/test-scaffold` then critically evaluate output vs own tests

**Deliverable:** Weather App with ≥5 meaningful JUnit 5 tests + Mockito. Fitness score ≥ 80%. Clean pre-commit.

---

## Session 4 — May 16 (8 hours): CI/CD + Agentic Architecture + cognitive-core Agents

### Block 4.1 — CI/CD: Jenkins (2h) — Theory + Praxis

- Basic concept: continuous integration, continuous deployment
- Jenkins installation, pipeline configuration (Jenkinsfile)
- Pipeline stages: build → test → quality → deploy
- Sonatype Nexus: concept, artifact repository (overview, Praxis optional)
- **Praxis:** Configure Jenkins pipeline for the Weather App

### Block 4.2 — Claude Code in CI/CD (1h) — Theory + Praxis

- `-p` / `--print` flag: non-interactive mode for pipelines
- `--output-format json` + `--json-schema`: structured CI output
- CLAUDE.md as context provider for CI-invoked Claude Code
- Session context isolation: why generation and review should be separate instances
- **Praxis:** Add Claude Code review step to Jenkins pipeline

### Block 4.3 — Prompt Engineering for Developers (1.5h) — Theory + Praxis

- Writing effective prompts: explicit criteria vs vague instructions
- Few-shot examples: format consistency, ambiguous case handling
- Structured output via `tool_use` and JSON schemas
- The interview pattern: Claude asks questions before implementing
- Iterative refinement: test-driven iteration, input/output examples
- Multi-pass review: per-file analysis + cross-file integration pass
- **Praxis:** Write prompts that produce reliable, structured code review output

### Block 4.4 — MCP: Model Context Protocol (1.5h) — Theory + Praxis

- What is MCP? Tools, resources, servers
- `.mcp.json`: project-level vs user-level configuration
- Environment variable expansion for credentials
- Writing effective tool descriptions (differentiation, boundaries, examples)
- Distributing tools across agents (principle of least privilege)
- **Praxis:** Connect Claude Code to a simple MCP server

### Block 4.5 — Agentic Architecture + cognitive-core Agents (2h) — Theory + Praxis

- **Agentic concepts (1h):**
  - The agentic loop: request → stop_reason check → tool execution → next iteration
  - Coordinator-subagent patterns (hub-and-spoke)
  - Subagent context: explicit passing, no automatic inheritance
  - Hooks: PostToolUse for data normalization, tool call interception for compliance
  - Task decomposition: fixed pipelines vs adaptive investigation
  - Context management: scratchpad files, session resumption, `/compact`
  - Error propagation: structured errors, local recovery, coverage gaps

- **cognitive-core as Architecture Case Study (30min):**
  - Full architecture: how hooks, skills, and agents compose into a quality system
  - `@code-standards-reviewer` agent: what it does, how it's configured
  - Agent definition: description, system prompt, tool restrictions
  - Fitness gates as programmatic enforcement (not prompt-based)
  - Student Lab Pack vs full enterprise configuration

- **cognitive-core Agent — Intelligent Review Partner (30min praxis):**
  - Activate `@code-standards-reviewer` agent
  - Review Weather App code: compliance summary, violations, architecture check
  - Each finding has provenance (documented, verified, inferred, automated)
  - **Key rule:** Agent does NOT fix code. Student reads, understands, fixes.

**Deliverable:** Jenkins pipeline with Claude Code integration. MCP server connected. Weather App reviewed by cognitive-core agent. All violations fixed.

---

## Session 5 — June 27 (4 hours): Context, Reliability & Final Presentations

### Block 5.1 — Context Management & Reliability (1h) — Theory

- Context window: what it is, why it matters
- Lost-in-the-middle effect, progressive summarization risks
- Scratchpad files for persisting findings across context limits
- Subagent delegation for managing verbose exploration
- Human-in-the-loop: escalation patterns, confidence calibration
- Error propagation across multi-agent systems

### Block 5.2 — Final Project Presentations (3h) — Praxis + Review

- Each student/team presents their Weather App
- **Grading against all criteria** (see below)
- Peer code review using cognitive-core `/code-review`
- Discussion: What did the LLM help with? What did it get wrong? What did you learn?

---

## Grading Criteria

### Traditional (kept from 2024, each -0.3 penalty):

| # | Criterion | Tool |
|---|-----------|------|
| 1 | Clean Code (Google style) | `eclipse-java-google-style.xml` |
| 2 | Clean CheckStyle | `google_checks.xml` |
| 3 | Clean PMD | `pmd-custom-ruleset.xml` |
| 4 | Clean SpotBugs | `mvn spotbugs:check` |
| 5 | Clean Maven Build | `mvn clean install` |
| 6 | Clean Git | No generated files, no IDE configs, no logs |
| 7 | Clean JUnit + Lifecycle | ≥5 tests, all annotations, assertions |
| 8 | Clean Mockito | Meaningful mocking examples |
| 9 | Clean Maven Directory | `src/main/java`, `src/test/java` |
| 10 | Clean Logging | Log4j2 only, no System.out/err |

### New LLM criteria (bonus, each +0.3):

| # | Criterion | Evidence |
|---|-----------|----------|
| 11 | CLAUDE.md + `.claude/rules/` configured | In repo |
| 12 | Custom slash command or skill | In `.claude/commands/` or `.claude/skills/` |
| 13 | cognitive-core fitness score ≥ 90% | `/fitness` output |
| 14 | Meaningful LLM usage | Commit history shows iterative refinement, not single vibe-coded dumps |

---

## cognitive-core Progressive Introduction

```
Session 1          Session 2              Session 3              Session 4              Session 5
(no AI)            (+ hooks)              (+ skills)             (+ agents)             (full framework)
   |                   |                      |                      |                      |
   v                   v                      v                      v                      v
[MAVEN]          [post-edit-lint]        [/pre-commit]         [@code-standards-      [presentation
[ANT]             [validate-bash]         [/fitness]             reviewer]              + peer review
                  [setup-env]             [/code-review]        [agentic loops]         with cognitive-
                  [compact-reminder]      [/test-scaffold]       [MCP tools]            core]
                       |                      |                      |                      |
                       v                      v                      v                      v
                  PASSIVE                ACTIVE                COLLABORATIVE          AUTONOMOUS
                  feedback               checking              review partner         quality workflow

Cognitive Load:   NONE          LOW              MEDIUM            MEDIUM-HIGH            HIGH
Student Agency:   MANUAL        RECEIVING        INITIATING        INTERPRETING           PRESENTING
```

---

## Mapping to Claude Certified Architect — Foundations Domains

| Cert Domain | Weight | Sessions | Topics |
|-------------|--------|----------|--------|
| D1: Agentic Architecture & Orchestration | 27% | 4.5 | Agentic loops, coordinator-subagent, hooks, task decomposition, session management |
| D2: Tool Design & MCP Integration | 18% | 4.4 | MCP servers/tools/resources, tool descriptions, `.mcp.json`, built-in tools |
| D3: Claude Code Configuration & Workflows | 20% | 2.4, 4.2 | CLAUDE.md, `.claude/rules/`, commands, skills, plan mode, `-p` flag, CI/CD |
| D4: Prompt Engineering & Structured Output | 20% | 4.3 | Few-shot, structured output, explicit criteria, iterative refinement |
| D5: Context Management & Reliability | 15% | 5.1 | Context windows, scratchpad, escalation, error propagation, human-in-the-loop |

---

## Required Tools & Prerequisites

| Requirement | Details |
|-------------|---------|
| Java | JDK 17+ |
| Maven | 3.9+ |
| Git | 2.39+ |
| Apache Ant | Latest (for Session 1 demo) |
| Jenkins | For CI/CD (Session 4) |
| Claude Code CLI | Claude Pro subscription ($20/month per student) |
| cognitive-core | `git clone https://github.com/mindcockpit-ai/cognitive-core.git` |
| IDE | Eclipse or IntelliJ (student choice) |
| GitHub | Student account |
