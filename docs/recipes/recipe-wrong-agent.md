# Recipe: Wrong Agent? How Task Redirect Saves You

> **Time**: 2 min read | **Level**: Beginner | **Applies to**: All languages

## Goal

Understand how cognitive-core's Task Redirect mechanism prevents wasted time when you accidentally pick the wrong agent for a task.

## Prerequisites

- cognitive-core installed (`./install.sh /path/to/project`)
- At least one agent available (any language/framework)

## The Problem

You ask an agent to do something outside its scope. It either gives poor results, hallucinates a workflow it was never designed for, or burns 30 minutes before you realize nothing useful came out.

This happens to everyone. Dennis Piskovatskov hit it in a real session: he asked `@solution-architect` to review code and suggest improvements. The agent tried its best, but solution-architect is built for business analysis and architecture decisions — not line-by-line code review. The output was vague and unhelpful.

## How cognitive-core Handles It

Every agent in cognitive-core has a **Task Redirect** section in its definition. When you pick the wrong agent, it recognizes the mismatch and redirects you instead of plowing ahead.

### Real Example (the Dennis scenario)

**User:**
```
@solution-architect review code, doc file and provide necessary improvements
```

**Agent response:**
```
This looks like a code review task — use @code-standards-reviewer or /code-review
instead. I specialize in business analysis and architecture decisions.
```

No wasted time. No misleading output. Just a redirect to the right tool.

## Agent Routing Cheat Sheet

| I want to...             | Use this                                    |
|--------------------------|---------------------------------------------|
| Review code quality      | `@code-standards-reviewer` or `/code-review` |
| Create tests             | `@test-specialist` or `/test-scaffold`       |
| Design architecture      | `@solution-architect`                        |
| Plan a sprint            | `@project-coordinator`                       |
| Research a library       | `@research-analyst`                          |
| Security scan            | `@security-analyst`                          |
| Optimize a query         | `@database-specialist`                       |
| Update framework         | `@skill-updater` or `/skill-sync`            |
| Angular migration        | `@angular-specialist`                        |
| Spring Boot migration    | `@spring-boot-specialist`                    |

## What If the Redirect Doesn't Trigger?

Task Redirect only fires for **clear mismatches** — keywords like "review code" sent to a non-reviewer agent, or "create tests" sent to the architect.

If your request is ambiguous, the agent may attempt it. Be specific:

- **Vague:** "Look at this and tell me what's wrong" (any agent might try)
- **Clear:** "Review code quality and naming conventions" (triggers redirect if wrong agent)

## Steps

### Step 1: Try the wrong agent (intentionally)

```
@solution-architect review code, doc file and provide necessary improvements
```

### Step 2: Observe the redirect

The agent recognizes this is a code review task and responds:

```
This looks like a code review task — use @code-standards-reviewer or /code-review
instead. I specialize in business analysis and architecture decisions.
```

### Step 3: Follow the redirect

```
@code-standards-reviewer review code, doc file and provide necessary improvements
```

Now you get a proper code review with Standards, Architecture, and Anti-patterns analysis.

## Expected Output

When you send a task to the wrong agent, you should see a short redirect message naming the correct agent or skill. No wasted processing, no misleading output. When you follow the redirect, you get the full, correct output from the right agent.

## The Full Routing Guide

For the complete keyword-to-agent mapping, including which keywords trigger which agent and all redirect rules, see [`.claude/AGENTS_README.md`](../../.claude/AGENTS_README.md).

## Next Steps

- [Code Review Workflow](recipe-code-review.md) -- deep dive on `/code-review` vs `@code-standards-reviewer`
- [Getting Started with Java](getting-started-java.md) -- full install-to-first-review walkthrough
- [Coordinator Workflow](recipe-coordinator-workflow.md) -- the coordinator's Smart Delegation prevents wrong-agent issues entirely
