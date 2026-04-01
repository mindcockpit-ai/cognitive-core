# cognitive-core Framework Overview

Visual architecture guide. All diagrams render in GitHub markdown.

---

## 1. Big Picture

Everything in one view — what cognitive-core is made of.

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            cognitive-core                                │
├──────────┬──────────┬──────────┬─────────────────────────────────────────┤
│          │          │          │                                         │
│  HOOKS   │  AGENTS  │  SKILLS  │  EXTENSION PACKS                        │
│  (safety)│  (team)  │  (tasks) │                                         │
│          │          │          │  ┌─────────────┐  ┌─────────────┐       │
│  15 hooks│ 10 agents│ 20 skills│  │ 11 Language │  │ 3 Database  │       │
│          │          │          │  │ Packs       │  │ Packs       │       │
│          │          │          │  └─────────────┘  └─────────────┘       │
├──────────┴──────────┴──────────┴─────────────────────────────────────────┤
│                                                                          │
│  ADAPTERS              CICD                TESTING                       │
│  6 platforms           Workflows           20 suites                     │
│  (Claude, Aider,       Docker, K8s         800+ assertions               │
│   IntelliJ, VSCode,    Monitoring                                        │
│   Ollama, OpenAI)                                                        │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  install.sh ──→ cognitive-core.conf ──→ .claude/ (or .cognitive-core/)   │
│  update.sh ──→ version.json (checksums) ──→ safe incremental update      │
└──────────────────────────────────────────────────────────────────────────┘
```

**One sentence**: cognitive-core installs hooks (safety), agents (team), and skills (tasks) into any project, with extension packs for languages and databases, adapters for different AI platforms, and 20 test suites to verify everything works.

---

## 2. Request Flow

What happens when a user types something in a Claude Code session.

```
    User types: "review this code for security issues"
         │
         ▼
┌───────────────────────────────────┐
│  SESSION START (once per session) │
│  setup-env.sh → env vars, branch  │
│  compact-reminder.sh → rules      │
│  session-resume → prior context   │
└────────────────┬──────────────────┘
                 │
                 ▼
┌───────────────────────────────────┐
│  CLAUDE (LLM) decides actions     │
│  Reads: CLAUDE.md, agent defs,    │
│         skill definitions         │
│                                   │
│  Routes to: @security-analyst     │
│  Plans: Read files, run grep,     │
│         generate review           │
└────────────────┬──────────────────┘
                 │
                 ▼  (for each tool call)
┌───────────────────────────────────┐
│  PreToolUse HOOKS                 │
│                                   │
│  Bash?   → validate-bash.sh       │
│  Read?   → validate-read.sh       │
│  Fetch?  → validate-fetch.sh      │
│                                   │
│  ┌──────────┐   ┌──────────────┐  │
│  │  DENY    │   │   ALLOW      │  │
│  │  (JSON)  │   │   (silent)   │  │
│  └────┬─────┘   └──────┬───────┘  │
│       │                 │         │
│   blocked           executes      │
└───────┘─────────────────┬─────────┘
                          │
                          ▼
               ┌──────────────────┐
               │  TOOL EXECUTES   │
               │  (bash, read,    │
               │   write, etc.)   │
               └────────┬─────────┘
                        │
                        ▼
┌───────────────────────────────────┐
│  PostToolUse HOOKS                │
│                                   │
│  Write/Edit? → validate-write.sh  │
│               → post-edit-lint.sh │
│  Fetch?      → post-fetch-cache   │
│                                   │
│  Cannot block (already happened)  │
│  Can warn via additionalContext   │
└────────────────┬──────────────────┘
                 │
                 ▼
┌───────────────────────────────────┐
│  RESPONSE to user                 │
└───────────────────────────────────┘
```

**Key insight**: Hooks are the only deterministic enforcement layer. Everything else (agent routing, skill steps, CLAUDE.md rules) is LLM-interpreted.

---

## 3. Hook System

The immune system — intercepts every tool call.

```
┌──────────────────────────────────────────────────────────────┐
│                       HOOK PROTOCOL                          │
│                                                              │
│  Claude Code                      Hook Script                │
│  ──────────                       ───────────                │
│                                                              │
│  Tool call    ──── stdin JSON ───→  INPUT=$(cat)             │
│  happens                            parse with _lib.sh       │
│                                                              │
│                                   ┌─ ALLOW: exit 0 (silent)  │
│               ◄── stdout JSON ───┤                           │
│                                   └─ DENY: JSON response     │
│                                      {"permissionDecision":  │
│                                       "deny",                │
│                                       "permissionDecision-   │
│                                        Reason": "..."}       │
└──────────────────────────────────────────────────────────────┘
```

### Hook Events

```
SESSION                    TOOL CALL                     AFTER
───────                    ─────────                     ─────

SessionStart               PreToolUse                    PostToolUse
  │                          │                              │
  ├─ setup-env.sh            ├─ validate-bash.sh            ├─ validate-write.sh
  ├─ compact-reminder.sh     ├─ validate-read.sh            ├─ post-edit-lint.sh
  └─ session-guard.sh        ├─ validate-fetch.sh           └─ post-fetch-cache.sh
                             ├─ angular-version-guard.sh
                             └─ spring-boot-version-guard.sh

  Injects context            Can DENY                       Can WARN only
  Cannot block               Can ASK (escalate)             Cannot block
```

### Security Levels

```
CC_SECURITY_LEVEL=

  minimal          standard (default)         strict
  ───────          ──────────────────         ──────
  8 patterns       + exfiltration             + domain allowlist
                   + encoded bypass           + CC_ALLOWED_DOMAINS
  rm -rf /         + pipe-to-shell
  git push -f      curl -d @file             Only approved domains
  DROP TABLE       base64 -d | sh            for web access
  ...              curl | sh
```

---

## 4. Agent Team

Hub-and-spoke — the project-coordinator routes to specialists.

```
                         ┌──────────────────┐
                         │       USER       │
                         └────────┬─────────┘
                                  │
                    ┌─────────────▼─────────────┐
                    │   project-coordinator     │
                    │   (Hub — Opus)            │
                    │                           │
                    │  Analyzes request         │
                    │  Matches keywords         │
                    │  Delegates to specialist  │
                    │  Synthesizes results      │
                    └──┬───┬───┬───┬───┬───┬────┘
                       │   │   │   │   │   │
         ┌─────────────┘   │   │   │   │   └──────────────┐
         ▼                 ▼   │   ▼   ▼                  ▼
  ┌─────────────┐  ┌──────────┐│┌──────────┐  ┌──────────────────┐
  │  solution-  │  │  code-   │││ test-    │  │   security-      │
  │  architect  │  │ standards│││ special- │  │   analyst        │
  │  (Opus)     │  │ reviewer ││  ist      │  │   (Opus)         │
  │             │  │ (Sonnet) │││ (Sonnet) │  │                  │
  │ "design"    │  │ "review" │││ "test"   │  │ "pentest"        │
  │ "workflow"  │  │ "lint"   │││ "cover"  │  │ "vulnerability"  │
  └─────────────┘  └──────────┘│└──────────┘  └──────────────────┘
                               │
                ┌──────────────┼──────────────┐
                ▼              ▼              ▼
         ┌───────────┐ ┌────────────┐ ┌─────────────┐
         │ research- │ │ database-  │ │ angular/    │
         │ analyst   │ │ specialist │ │ spring-boot │
         │ (Opus)    │ │ (Opus)     │ │ specialist  │
         │           │ │            │ │ (Sonnet)    │
         │ "research"│ │ "query"    │ │ "migrate"   │
         │ "library" │ │ "index"    │ │ "component" │
         └───────────┘ └────────────┘ └─────────────┘
```

### Least-Privilege

```
  Agent                    CAN use              CANNOT use
  ─────                    ───────              ──────────
  code-standards-reviewer  Bash,Read,Grep,Edit  WebFetch, WebSearch
  research-analyst         Read,Grep,WebSearch  Write, Edit
  skill-updater            Bash,Read,Write,Glob WebFetch, WebSearch
  security-analyst         ALL tools            (full access needed)
```

---

## 5. Skill Anatomy

How a SKILL.md is structured and how ability types work.

```
┌──────────────────────────────────────────────────────┐
│  core/skills/smoke-test/SKILL.md                     │
├──────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────────────────────────────────────┐        │
│  │  YAML FRONTMATTER (harness-enforced)     │        │
│  │  name: smoke-test                        │   D    │
│  │  allowed-tools: [Bash, Read, Grep]       │   E    │
│  │  user-invocable: true                    │   T    │
│  └──────────────────────────────────────────┘   E    │
│                                                 R    │
│  ┌──────────────────────────────────────────┐   M    │
│  │  ABILITY REGISTRY (type annotations)     │   I    │
│  │                                          │   N    │
│  │  preflight      [D]   → preflight.sh     │   I    │
│  │  execute-test   [D]   → execute-test.sh  │   S    │
│  │  format-table   [S]   → LLM generates    │   T    │
│  │  create-issue   [D/S] → create-issue.sh  │   I    │
│  │  offer-closures [H]   → human decides    │   C    │
│  └──────────────────────────────────────────┘        │
│                                                      │
│  ┌──────────────────────────────────────────┐        │
│  │  WORKFLOW (LLM-interpreted prose)        │        │
│  │                                          │   S    │
│  │  Step 1 [D]: Run preflight.sh            │   T    │
│  │  Step 2 [D]: Run execute-test.sh         │   O    │
│  │  Step 3 [S]: Render markdown table       │   C    │
│  │  Step 4 [D]: Run check-issues.sh         │   H    │
│  │  Step 5 [S]: Compose issue body          │   A    │
│  │  Step 6 [D/S]: Run create-issue.sh       │   S    │
│  │  Step 7 [H]: Ask human about closures    │   T    │
│  └──────────────────────────────────────────┘   I    │
│                                                 C    │
└──────────────────────────────────────────────────────┘
```

### Ability Types — Who Decides, Who Executes

```
  Type    Flow                              Enforcement
  ────    ────                              ───────────

  D       Script ──→ Script ──→ Output      Full (testable, deterministic)

  D/S     LLM ──(input)──→ Script ──→ Out   Partial (mutation is deterministic)

  S/D     Script ──(data)──→ LLM ──→ Out    Partial (input is controlled)

  S       LLM ──→ LLM ──→ Output            None (variance acceptable)

  H       Human ──→ decides ──→ Output       External (requires judgment)
```

### Scripts Directory (D-type abilities live here)

```
  core/skills/smoke-test/
  ├── SKILL.md                    ← orchestrator (sequences abilities)
  └── scripts/
      ├── _smoke-lib.sh           ← shared config/helpers
      ├── preflight.sh            ← [D] check server reachability
      ├── execute-test.sh         ← [D] run test, validate JSON
      ├── check-issues.sh         ← [D] search GitHub for existing issues
      ├── create-issue.sh         ← [D/S] create issue with dedup
      └── list-open-issues.sh     ← [D] list open issues as JSON
```

---

## 6. Installation & Update

How cognitive-core gets into your project.

```
┌──────────────────────────────────────────────────────────────────────┐
│                           INSTALL FLOW                               │
│                                                                      │
│  ./install.sh /path/to/project                                       │
│       │                                                              │
│       ▼                                                              │
│  ┌───────────────┐  ┌───────────────┐  ┌──────────────────────┐      │
│  │ 1. PROMPTS    │─→│ 2. DETECT     │─→│ 3. SELECT ADAPTER    │      │
│  │               │  │               │  │                      │      │
│  │ Project name  │  │ Language      │  │ Claude  → .claude/   │      │
│  │ Language      │  │ Database      │  │ Aider   → .cog-core/ │      │
│  │ Database      │  │ Platform      │  │ IntelliJ→ .cog-core/ │      │
│  │ Security lvl  │  │               │  │ VSCode  → .vscode/   │      │
│  └───────────────┘  └───────────────┘  └──────────┬───────────┘      │
│                                                   │                  │
│       ┌───────────────────────────────────────────┘                  │
│       ▼                                                              │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ 4. COPY COMPONENTS via adapter                               │    │
│  │                                                              │    │
│  │  cognitive-core.conf  ← generated from user answers          │    │
│  │  settings.json        ← hooks + permissions                  │    │
│  │  CLAUDE.md            ← project rules (or CONVENTIONS.md)    │    │
│  │  hooks/*.sh           ← selected hooks                       │    │
│  │  agents/*.md          ← selected agents                      │    │
│  │  skills/*/SKILL.md    ← selected skills                      │    │
│  │  language-pack/*      ← if language selected                 │    │
│  │  database-pack/*      ← if database selected                 │    │
│  │  .gitignore merge     ← from gitignore-base + pack fragments │    │
│  └──────────────────────────────────────────────┬───────────────┘    │
│                                                 │                    │
│       ┌─────────────────────────────────────────┘                    │
│       ▼                                                              │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ 5. WRITE MANIFEST                                            │    │
│  │ version.json ← SHA256 checksums of every installed file      │    │
│  └──────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                           UPDATE FLOW                                │
│                                                                      │
│  ./update.sh /path/to/project                                        │
│       │                                                              │
│       ▼                                                              │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ 1. Read version.json                                         │    │
│  │ 2. For each tracked file:                                    │    │
│  │    current_hash  = SHA256(installed file)                    │    │
│  │    manifest_hash = version.json recorded hash                │    │
│  │    framework_hash = SHA256(framework source file)            │    │
│  │                                                              │    │
│  │    ┌─ current == manifest?                                   │    │
│  │    │  YES → user did NOT modify → safe to update             │    │
│  │    │  NO  → user modified → SKIP (warn to review)            │    │
│  │    └─────────────────────────────────────────────            │    │
│  │                                                              │    │
│  │ 3. Copy new files not in manifest (new framework features)   │    │
│  │ 4. Write updated version.json                                │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  KEY INVARIANT: update never overwrites your customizations          │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 7. Extension Points

Three ways to extend cognitive-core without modifying the core.

```
┌──────────────────────────────────────────────────────────────────┐
│                       EXTENSION POINTS                           │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  LANGUAGE PACKS (11)                                       │  │
│  │                                                            │  │
│  │  language-packs/<lang>/                                    │  │
│  │  ├── skills/         ← language-specific skills            │  │
│  │  ├── rules/          ← path-scoped coding rules            │  │
│  │  ├── gitignore.frag  ← merged into project .gitignore      │  │
│  │  └── pack.conf       ← defaults (linter, formatter, etc.)  │  │
│  │                                                            │  │
│  │  angular  csharp  go  java  node  perl  python             │  │
│  │  react  rust  spring-boot  struts-jsp                      │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  DATABASE PACKS (3)                                        │  │
│  │                                                            │  │
│  │  database-packs/<db>/                                      │  │
│  │  ├── skills/         ← DB-specific patterns & optimization │  │
│  │  ├── rules/          ← SQL conventions                     │  │
│  │  └── pack.conf       ← defaults (client tool, port, etc.)  │  │
│  │                                                            │  │
│  │  oracle  postgresql  mysql                                 │  │
│  └────────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │  ADAPTERS (6)                                              │  │
│  │                                                             │  │
│  │  Each adapter implements 5 functions:                       │  │
│  │  _adapter_install_hook                                      │  │
│  │  _adapter_install_agent                                     │  │
│  │  _adapter_install_skill                                     │  │
│  │  _adapter_generate_settings                                 │  │
│  │  _adapter_generate_project_readme                           │  │
│  │                                                             │  │
│  │  Platform      Install Dir        Project File              │  │
│  │  ──────────    ─────────────      ─────────────             │  │
│  │  Claude Code   .claude/           CLAUDE.md                 │  │
│  │  Aider         .cognitive-core/   CONVENTIONS.md            │  │
│  │  IntelliJ      .cognitive-core/   DEVOXXGENIE.md            │  │
│  │  VS Code       .vscode/           copilot-instructions      │  │
│  │  Ollama        .cognitive-core/   CONVENTIONS.md            │  │
│  │  OpenAI        .cognitive-core/   CONVENTIONS.md            │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Summary: What Goes Where

| Question | Answer |
|----------|--------|
| Where is safety enforced? | `core/hooks/` — the only deterministic layer |
| Where are AI roles defined? | `core/agents/` — YAML frontmatter + instructions |
| Where are tasks defined? | `core/skills/` — SKILL.md + optional scripts/ |
| Where do I add a language? | `language-packs/<lang>/` |
| Where do I add a database? | `database-packs/<db>/` |
| Where do I add a platform? | `adapters/<platform>/` |
| Where is everything configured? | `cognitive-core.conf` (one file) |
| Where are tests? | `tests/suites/` — 20 suites, 800+ assertions |
| How do I install? | `./install.sh /path/to/project` |
| How do I update safely? | `./update.sh /path/to/project` |
