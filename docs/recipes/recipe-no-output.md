# Recipe: Troubleshooting — Nothing Happened

> **Time**: ~3 min read | **Level**: Beginner | **Applies to**: All languages

## Goal

Diagnose and fix common setup issues when cognitive-core commands produce no output, wrong output, or seem to have no effect.

## Prerequisites

- cognitive-core cloned somewhere on your machine
- A project where you attempted to install cognitive-core

## Steps

### Step 1: Check if cognitive-core is installed

```bash
ls .claude/cognitive-core/version.json
```

**If the file exists:** cognitive-core is installed. Continue to Step 2.

**If the file does not exist:** cognitive-core was never installed on this project. Run:

```bash
./path/to/cognitive-core/install.sh /path/to/your-project
```

### Step 2: Check if hooks are loaded

```bash
cat .claude/settings.json | python3 -m json.tool | grep -A2 hooks
```

**Expected:** You should see `hooks` entries pointing to `.claude/cognitive-core/hooks/`.

**If missing:** The settings file was not generated or was overwritten. Reinstall:

```bash
./path/to/cognitive-core/install.sh /path/to/your-project --force
```

### Step 3: Check the configuration file

```bash
cat cognitive-core.conf
```

**Expected:** You should see key settings like:

```
CC_LANGUAGE=java
CC_ARCHITECTURE=ddd
CC_TEST_COMMAND="mvn test"
CC_GITHUB_REPO="your-org/your-repo"
```

**Common issues:**
- `CC_LANGUAGE` is empty or wrong -- agents and skills cannot adapt to your stack
- `CC_TEST_COMMAND` is missing -- `/fitness` and `@test-specialist` cannot run tests
- `CC_GITHUB_REPO` is missing -- `/project-board` and issue-related features fail silently

### Step 4: Check if agents are registered

```bash
ls .claude/agents/ 2>/dev/null || echo "No agents directory"
```

**Expected:** Agent markdown files like `code-standards-reviewer.md`, `test-specialist.md`.

**If the directory is empty or missing:** Agents were not installed. Reinstall:

```bash
./path/to/cognitive-core/install.sh /path/to/your-project --force
```

### Step 5: Check GitHub authentication

```bash
gh auth status
```

**Expected:** `Logged in to github.com as your-username`

**If not authenticated:** Some features require GitHub access (project board, issue reading):

```bash
gh auth login
```

### Step 6: Check skill availability

Start a Claude Code session and list available skills:

```
What skills and agents are available?
```

**Expected:** Claude should list agents (coordinator, reviewer, architect, tester, etc.) and skills (/code-review, /pre-commit, /fitness, etc.).

**If nothing is listed:** The CLAUDE.md file may be missing or incomplete. Check:

```bash
cat CLAUDE.md | head -20
```

It should reference cognitive-core agents and skills. If it does not, reinstall.

### Step 7: Nuclear option — force reinstall

If nothing else works, force a clean reinstall:

```bash
./path/to/cognitive-core/install.sh /path/to/your-project --force
```

This regenerates all hooks, agents, skills, settings, and CLAUDE.md without deleting your project code.

## Quick Diagnosis Table

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `/code-review` does nothing | Skills not installed | Reinstall with `--force` |
| `@test-specialist` not recognized | Agents not registered | Check `.claude/agents/` directory |
| `/fitness` says "no test command" | `CC_TEST_COMMAND` not set | Edit `cognitive-core.conf` |
| `/project-board` fails silently | `CC_GITHUB_REPO` not set or `gh` not authed | Set config + `gh auth login` |
| Hooks don't fire | `settings.json` missing hook entries | Reinstall with `--force` |
| Wrong language rules | `CC_LANGUAGE` set incorrectly | Edit `cognitive-core.conf`, restart session |
| Everything works but no language-specific skills | Language pack not available | Check `language-packs/` for your language |

## Expected Output

After following the relevant fix steps, starting a new Claude Code session should show the first-session welcome message listing all agents and skills. Commands like `/code-review`, `@test-specialist`, and `/fitness` should produce structured output.

## Next Steps

- [Getting Started with Java](getting-started-java.md) -- full install walkthrough for Java
- [Getting Started with Python](getting-started-python.md) -- full install walkthrough for Python
- [Getting Started with Node.js](getting-started-node.md) -- full install walkthrough for Node
- [Wrong Agent?](recipe-wrong-agent.md) -- if commands work but give unexpected results
