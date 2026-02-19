---
name: tech-intel
description: Technology intelligence gathering. Web research for dependency updates, security advisories, and ecosystem developments relevant to your stack.
user-invocable: true
disable-model-invocation: true
allowed-tools: Bash, Read, Write, WebSearch, WebFetch, Glob
catalog_description: Dependency updates, security advisories, and ecosystem intelligence.
---

# Tech Intel — Technology Intelligence Digest

Researches technology developments relevant to your project stack. Reads
`CC_LANGUAGE`, `CC_DATABASE`, and `CC_MCP_SERVERS` from `cognitive-core.conf`
to focus research on your actual dependencies.

## Arguments

- `$ARGUMENTS` -- optional: `--date=YYYY-MM-DD`, `--topic=<focus>`
- Topics: `claude`, `stack`, `security`, `all` (default: `all`)

## Research Topics

### Priority 1: Claude Code and Anthropic (DAILY)
- Claude Code CLI releases and changelog
- New model capabilities
- Skills and agents architecture changes
- MCP server ecosystem updates

### Priority 2: Project Stack (WEEKLY)
Based on `CC_LANGUAGE` and `CC_DATABASE`:
- Language runtime releases and security patches
- Framework and ORM updates
- Database driver and tooling changes
- Notable new packages in the ecosystem

### Priority 3: Industry Trends (WEEKLY)
- AI coding assistant developments
- Agentic development patterns
- Developer productivity research

## Instructions

### Step 1: Research

Search for recent developments (last 24h for daily, last 7 days for weekly):

- `"claude code" changelog OR release OR update`
- `anthropic claude model update [current year]`
- Stack-specific queries derived from `CC_LANGUAGE` and `CC_DATABASE`
- Security advisories for project dependencies

### Step 2: Analyze and Prioritize

For each finding, assess:
- **Relevance**: Does it affect this project? (HIGH/MEDIUM/LOW)
- **Urgency**: Act now? (IMMEDIATE/SOON/INFORMATIONAL)
- **Impact**: What changes if adopted? (ARCHITECTURE/WORKFLOW/COSMETIC)

### Step 3: Generate Digest

Save to `${CC_SESSION_DOCS_DIR:-docs}/tech-intel/YYYY-MM-DD.md`:

```markdown
# Tech Intel Digest - YYYY-MM-DD

## Headlines
- [Most important finding]
- [Second finding]

## Claude Code and Anthropic
### [Finding Title]
**Relevance**: HIGH | **Urgency**: IMMEDIATE
**Source**: [URL]
**Summary**: [2-3 sentences]
**Action**: [What to do, if anything]

## Project Stack
### [Finding Title]
...

## Security Advisories
### [Finding Title]
...

## Recommended Reading
1. [Title](URL) - [Why it matters] (**MUST READ**)
2. [Title](URL) - [Why it matters] (Recommended)

## Actions
- [ ] [Concrete action item]
```

### Step 4: Retention

- Keep last 30 digests
- Notable findings should be captured in MEMORY.md or CLAUDE.md

## See Also

- `/project-status` -- Current project state
- `cognitive-core.conf` -- Stack configuration
