#!/usr/bin/env python3
"""
cognitive-core IntelliJ configuration generator.

Translates cognitive-core configuration into IntelliJ-compatible files:
  --mode settings     -> .devoxxgenie.yaml
  --mode conventions  -> DEVOXXGENIE.md
  --mode mcp-config   -> MCP server configuration snippet
  --mode all          -> all of the above

Usage:
  python3 generate.py --mode all --project-dir /path/to/project \
      --install-dir /path/to/project/.cognitive-core \
      --config-file /path/to/project/cognitive-core.conf
"""
import argparse
import os
import re
import subprocess
import sys
from pathlib import Path


def load_config(config_file: str) -> dict:
    """Load cognitive-core.conf by sourcing it in bash and capturing variables."""
    if not config_file or not os.path.isfile(config_file):
        return {}

    cmd = f'set -a; source "{config_file}" 2>/dev/null; env | grep "^CC_"'
    try:
        result = subprocess.run(
            ["bash", "-c", cmd], capture_output=True, text=True, timeout=5
        )
        config = {}
        for line in result.stdout.strip().split("\n"):
            if "=" in line:
                key, _, value = line.partition("=")
                config[key] = value
        return config
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {}


def generate_settings(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate .devoxxgenie.yaml from cognitive-core configuration."""
    conf_path = os.path.join(project_dir, ".devoxxgenie.yaml")

    model = config.get("CC_INTELLIJ_MODEL", config.get("CC_AIDER_MODEL", "qwen2.5-coder:32b"))
    ollama_base = config.get("CC_INTELLIJ_OLLAMA_BASE", config.get("CC_AIDER_OLLAMA_BASE", "http://localhost:11434"))
    lint_cmd = config.get("CC_LINT_COMMAND", "echo no-lint")
    test_cmd = config.get("CC_TEST_COMMAND", "echo no-tests")
    project_name = config.get("CC_PROJECT_NAME", "project")

    lines = [
        f"# cognitive-core generated IntelliJ / DevoxxGenie configuration",
        f"# Platform: intellij + local LLM",
        f"# Project: {project_name}",
        f"",
        f"# LLM provider configuration",
        f"provider: ollama",
        f"model: {model}",
        f"ollama_url: {ollama_base}",
        f"",
        f"# Lint and test commands",
        f"lint_command: {lint_cmd}",
        f"test_command: {test_cmd}",
        f"",
        f"# Context files (always loaded)",
        f"context_files:",
        f"  - DEVOXXGENIE.md",
    ]

    # Add agent docs as context
    agents_dir = os.path.join(install_dir, "agents")
    if os.path.isdir(agents_dir):
        for agent_file in sorted(os.listdir(agents_dir)):
            if agent_file.endswith(".md"):
                rel_path = os.path.relpath(
                    os.path.join(agents_dir, agent_file), project_dir
                )
                lines.append(f"  - {rel_path}")

    lines.extend([
        f"",
        f"# MCP server (Layer 2)",
        f"mcp_server:",
        f"  enabled: true",
        f"  command: python3",
        f"  args:",
        f"    - .cognitive-core/mcp-server/server.py",
        f"  transport: stdio",
    ])

    with open(conf_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def generate_conventions(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate DEVOXXGENIE.md from config, safety rules, and template."""
    conv_path = os.path.join(project_dir, "DEVOXXGENIE.md")

    project_name = config.get("CC_PROJECT_NAME", "project")
    language = config.get("CC_LANGUAGE", "unknown")
    architecture = config.get("CC_ARCHITECTURE", "none")
    database = config.get("CC_DATABASE", "none")
    lint_cmd = config.get("CC_LINT_COMMAND", "echo no-lint")
    test_cmd = config.get("CC_TEST_COMMAND", "echo no-tests")
    main_branch = config.get("CC_MAIN_BRANCH", "main")
    commit_format = config.get("CC_COMMIT_FORMAT", "conventional")
    commit_scopes = config.get("CC_COMMIT_SCOPES", "core")
    src_root = config.get("CC_SRC_ROOT", "src")
    test_root = config.get("CC_TEST_ROOT", "tests")
    compact_rules = config.get("CC_COMPACT_RULES", "")

    # Check for template
    template_path = os.path.join(
        os.path.dirname(__file__), "templates", "DEVOXXGENIE.md.tmpl"
    )
    if os.path.isfile(template_path):
        with open(template_path, encoding="utf-8") as f:
            content = f.read()

        # Replace placeholders
        replacements = {
            "{{CC_PROJECT_NAME}}": project_name,
            "{{CC_LANGUAGE}}": language,
            "{{CC_ARCHITECTURE}}": architecture,
            "{{CC_DATABASE}}": database,
            "{{CC_LINT_COMMAND}}": lint_cmd,
            "{{CC_TEST_COMMAND}}": test_cmd,
            "{{CC_MAIN_BRANCH}}": main_branch,
            "{{CC_COMMIT_FORMAT}}": commit_format,
            "{{CC_COMMIT_SCOPES}}": commit_scopes,
            "{{CC_SRC_ROOT}}": src_root,
            "{{CC_TEST_ROOT}}": test_root,
            "{{CC_COMPACT_RULES}}": compact_rules,
        }
        for placeholder, value in replacements.items():
            content = content.replace(placeholder, value)

        # Extract safety rules from validate-bash.sh if available
        safety_rules = _extract_safety_rules(install_dir)
        content = content.replace("{{SAFETY_RULES}}", safety_rules)

        # Build agent context references
        agent_refs = _build_agent_refs(install_dir)
        content = content.replace("{{AGENT_CONTEXT}}", agent_refs)

        with open(conv_path, "w", encoding="utf-8") as f:
            f.write(content)
    else:
        # Direct generation without template
        safety_rules = _extract_safety_rules(install_dir)
        agent_refs = _build_agent_refs(install_dir)

        content = f"""# Project Conventions — {project_name}

## Project Identity
- **Project**: {project_name}
- **Language**: {language}
- **Architecture**: {architecture}
- **Database**: {database}

## Code Standards
- Follow {language} community best practices
- Run lint before every commit: `{lint_cmd}`
- Run tests: `{test_cmd}`
- All new code must have tests

## Git Conventions
- Main branch: `{main_branch}`
- Commit format: `type(scope): subject` ({commit_format} format)
- Scopes: {commit_scopes}
- NO AI/tool references in commit messages

## Safety Rules (CRITICAL — MUST FOLLOW)
{safety_rules}

## Architecture
Pattern: **{architecture}**
Source root: `{src_root}`
Test root: `{test_root}`

## Key Rules
{compact_rules}

## Agent Context
{agent_refs}
"""
        with open(conv_path, "w", encoding="utf-8") as f:
            f.write(content)


def _extract_safety_rules(install_dir: str) -> str:
    """Extract safety rules from validate-bash.sh hook."""
    hook_path = os.path.join(install_dir, "hooks", "validate-bash.sh")
    if not os.path.isfile(hook_path):
        return _default_safety_rules()

    rules = []
    try:
        with open(hook_path, encoding="utf-8") as f:
            content = f.read()

        reason_pattern = re.compile(r'REASON="Blocked:\s*(.+?)"')
        for match in reason_pattern.finditer(content):
            reason = match.group(1).strip()
            rules.append(f"- NEVER: {reason}")
    except (OSError, UnicodeDecodeError):
        return _default_safety_rules()

    if not rules:
        return _default_safety_rules()

    return "\n".join(rules)


def _default_safety_rules() -> str:
    """Default safety rules when hook is not available."""
    return """- NEVER execute: rm -rf targeting system-critical paths (/, /etc, /usr, /var, /home)
- NEVER execute: git push --force to main/master
- NEVER execute: git reset --hard (destructive, may lose work)
- NEVER execute: DROP TABLE or TRUNCATE TABLE
- NEVER execute: DELETE FROM without WHERE clause
- NEVER execute: rm .git directory
- NEVER execute: chmod 777 (insecure permissions)
- NEVER execute: git clean -f without -n dry-run
- NEVER pipe curl/wget output to sh/bash (supply chain risk)
- NEVER use base64 -d | sh (encoded command execution)
- NEVER use eval with command substitution
- NEVER pipe environment variables to external commands"""


def _build_agent_refs(install_dir: str) -> str:
    """Build agent context reference section."""
    agents_dir = os.path.join(install_dir, "agents")
    if not os.path.isdir(agents_dir):
        return "No agent documentation installed."

    refs = []
    for agent_file in sorted(os.listdir(agents_dir)):
        if agent_file.endswith(".md"):
            name = agent_file.replace(".md", "").replace("-", " ").title()
            rel_path = os.path.join(".cognitive-core", "agents", agent_file)
            refs.append(f"- **{name}**: `{rel_path}`")

    if not refs:
        return "No agent documentation installed."

    return (
        "Agent documentation is available for reference:\n"
        + "\n".join(refs)
        + "\n\nUse their guidance when working in their specialist domains."
    )


def generate_mcp_config(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate MCP server configuration snippet for IDE plugins."""
    mcp_config_path = os.path.join(install_dir, "mcp-config.json")
    project_name = config.get("CC_PROJECT_NAME", "project")

    import json
    mcp_config = {
        "mcpServers": {
            "cognitive-core": {
                "command": "python3",
                "args": [
                    os.path.join(install_dir, "mcp-server", "server.py")
                ],
                "env": {
                    "CC_PROJECT_DIR": project_dir,
                    "CC_INSTALL_DIR": install_dir,
                },
            }
        }
    }

    with open(mcp_config_path, "w", encoding="utf-8") as f:
        json.dump(mcp_config, f, indent=2)
        f.write("\n")


def main():
    parser = argparse.ArgumentParser(
        description="Generate IntelliJ configuration from cognitive-core"
    )
    parser.add_argument(
        "--mode",
        required=True,
        choices=["settings", "conventions", "mcp-config", "all"],
        help="Which files to generate",
    )
    parser.add_argument(
        "--project-dir", required=True, help="Target project directory"
    )
    parser.add_argument(
        "--install-dir", required=True, help="cognitive-core install directory"
    )
    parser.add_argument(
        "--config-file", default="", help="Path to cognitive-core.conf"
    )

    args = parser.parse_args()
    config = load_config(args.config_file)

    generators = {
        "settings": generate_settings,
        "conventions": generate_conventions,
        "mcp-config": generate_mcp_config,
    }

    if args.mode == "all":
        for mode, gen_fn in generators.items():
            gen_fn(args.project_dir, args.install_dir, config)
    else:
        generators[args.mode](args.project_dir, args.install_dir, config)


if __name__ == "__main__":
    main()
