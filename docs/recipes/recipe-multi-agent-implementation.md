# Recipe: Multi-Agent Implementation from Research

> **Time**: ~3 min read | **Level**: Advanced | **Audience**: Developers implementing framework changes backed by research

## Goal

Implement a well-scoped code change using multi-agent coordination: a primary implementation agent, plus specialist agents for security review, standards compliance, and test creation. The prompt structure ensures scoped delivery, evidence-based design, and safety verification.

## Prerequisites

- cognitive-core installed (`./install.sh /path/to/project`)
- A GitHub issue with acceptance criteria
- Research or evidence backing the change (benchmark, analysis, RFC)
- Agents available: `@code-standards-reviewer`, `@test-specialist`, `@security-analyst`

## When to Use

- Implementing changes that touch security-sensitive code (hooks, validators)
- Changes derived from research findings (benchmarks, comparative studies)
- Cross-cutting changes affecting multiple components (language packs, utilities)
- Any change where "works the same but faster/better" must be verifiable

## Prompt Template

```
Implement GitHub issue #[N]: [title]

## Context

[Link to research paper, benchmark, or evidence backing this change]
[Link to the GitHub issue with acceptance criteria]

## Scope: Phase [N] only ([description])

1. [Specific change 1 — what file, what function, what behavior]
2. [Specific change 2]
3. [Specific change 3]

## DO NOT (scope guard)

- [Explicitly list what is out of scope]
- [Files/components that should NOT be touched]
- [Future phases that should NOT be started]

## Constraints

- [Behavioral constraint: must work identically with/without the new tool]
- [Testing constraint: how to simulate degraded environment]
- [Convention constraint: naming patterns, code style, existing patterns to follow]
- [Safety constraint: what must be preserved]

## Agents to use

- @code-standards-reviewer: review final changes against CLAUDE.md
- @test-specialist: create test cases for [specific scenarios]
- @security-analyst: verify [security-critical component] patterns preserved

## After implementation

- [Verification steps]
- [Branch/commit/PR instructions]
```

## Example: ripgrep Wrapper (Issue #134)

This example shows the prompt used to implement a performance wrapper backed by a peer-reviewed benchmark paper.

```
Implement GitHub issue #134: adopt ripgrep (rg) with grep fallback
for hook and utility scripts.

## Context

Research paper with benchmarks and peer-reviewed wrapper implementation:
  docs/research/2026-03-24-ripgrep-vs-grep-benchmark.md
  (Section 9 has the corrected _cc_rg() wrapper with flag translation)

Issue: https://github.com/mindcockpit-ai/cognitive-core/issues/134

## Scope: Phase 1 only (wrapper + highest-impact fitness-checks)

1. Add `_cc_rg()` wrapper function to `core/hooks/_lib.sh`
   - Auto-detects rg, falls back to grep -r
   - Translates --include/--exclude to rg -g syntax
   - Strips -r and -E (rg defaults)
   - Supports --all flag for --no-ignore mode
   - Follow _cc_compute_sha256() pattern (detect, never auto-install)

2. Migrate fitness-checks.sh in language packs that use recursive grep

3. DO NOT migrate:
   - Hook scripts (all pipe grep, zero rg benefit)
   - Utilities (Phase 3)
   - Do NOT auto-install rg (framework convention)

## Constraints

- Every migrated grep call MUST work identically with and without rg
- Test by running: PATH_NO_RG=$(echo "$PATH" | tr ':' '\n' |
  grep -v homebrew | tr '\n' ':') to simulate rg-absent environment
- Do not change behavior — only the underlying tool
- grep calls inside _lib.sh itself should NOT use the wrapper (bootstrap)
- Support --all flag for agents that need to scan gitignored files

## Agents to use

- @code-standards-reviewer: review the final changes against CLAUDE.md
- @test-specialist: create test cases for wrapper (rg present + rg absent)
- @security-analyst: verify validate-bash.sh security patterns preserved

## After implementation

- Run all fitness-checks manually with a sample project to verify
- Create branch, commit, push, open PR to main
```

## Why This Structure Works

| Principle | How it's applied |
|-----------|-----------------|
| **Scoped** | Explicit phase boundary + DO NOT list prevents scope creep |
| **Evidence-based** | Points to peer-reviewed research, not assumptions |
| **Multi-agent** | 3 specialist agents for review, testing, security |
| **Testable** | Explicit degraded-environment simulation command |
| **Safe** | Bootstrap protection, behavioral equivalence requirement |
| **Bounded** | Clear "after implementation" checklist |

## Common Pitfalls

| Pitfall | Prevention |
|---------|-----------|
| Scope creep — "while we're here, let's also..." | Explicit DO NOT list in prompt |
| Untested fallback path | Require rg-absent test in constraints |
| Breaking existing behavior | "Do not change behavior" constraint |
| Agent doing research instead of implementing | "implement" verb + specific file list |
| Missing security review on sensitive hooks | Named `@security-analyst` with specific target |

## Variations

### Lighter version (single agent, no specialists)

For simpler changes that don't touch security code:

```
Implement issue #[N]. Context: [link].
Scope: [1-2 specific changes].
DO NOT: [out of scope items].
After: run tests, commit, push.
```

### Research-first version (analysis before implementation)

When the evidence doesn't exist yet:

```
Before implementing issue #[N], research:
1. [What data is needed]
2. [What alternatives exist]

Use @research-analyst for external research.
Output: recommendation with evidence, then implement.
```

## See Also

- `recipe-code-review.md` — Review workflow using `/code-review` and `@code-standards-reviewer`
- `recipe-security-scan.md` — Security-focused analysis patterns
- `recipe-architecture-analysis.md` — Architecture decision analysis
