#!/usr/bin/env python3
"""
cognitive-core Aider configuration generator.

Translates cognitive-core configuration into Aider-compatible files:
  --mode settings     → .aider.conf.yml
  --mode conventions  → CONVENTIONS.md
  --mode ignore       → .aiderignore
  --mode launcher     → cc-aider-start.sh
  --mode all          → all of the above

Usage:
  python3 generate.py --mode all --project-dir /path/to/project \\
      --install-dir /path/to/project/.cognitive-core \\
      --config-file /path/to/project/cognitive-core.conf
"""
import argparse
import os
import stat
import sys
from pathlib import Path

# Shared utilities — single source of truth (#139 P3)
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from _shared.generate_utils import load_config, extract_safety_rules, build_agent_refs


def generate_settings(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate .aider.conf.yml from cognitive-core configuration."""
    conf_path = os.path.join(project_dir, ".aider.conf.yml")

    model = config.get("CC_AIDER_MODEL", "qwen2.5-coder:32b")
    edit_format = config.get("CC_AIDER_EDIT_FORMAT", "diff")
    lint_cmd = config.get("CC_LINT_COMMAND", "echo no-lint")
    test_cmd = config.get("CC_TEST_COMMAND", "echo no-tests")
    project_name = config.get("CC_PROJECT_NAME", "project")

    lines = [
        "# cognitive-core generated Aider configuration",
        "# Platform: aider + ollama",
        f"# Project: {project_name}",
        "",
        "# Model configuration",
        f"model: ollama_chat/{model}",
        f"editor-model: ollama_chat/{model}",
        "",
        "# Edit format",
        f"edit-format: {edit_format}",
        "",
        "# Auto-lint after edits",
        "auto-lint: true",
        f"lint-cmd: {lint_cmd}",
        "",
        "# Auto-test after edits",
        "auto-test: false",
        f"test-cmd: {test_cmd}",
        "",
        "# Read-only context files (always in context)",
        "read:",
        "  - CONVENTIONS.md",
    ]

    # Add agent docs as read-only context
    agents_dir = os.path.join(install_dir, "agents")
    if os.path.isdir(agents_dir):
        for agent_file in sorted(os.listdir(agents_dir)):
            if agent_file.endswith(".md"):
                rel_path = os.path.relpath(
                    os.path.join(agents_dir, agent_file), project_dir
                )
                lines.append(f"  - {rel_path}")

    with open(conf_path, "w") as f:
        f.write("\n".join(lines) + "\n")


def generate_conventions(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate CONVENTIONS.md from config, safety rules, and template."""
    conv_path = os.path.join(project_dir, "CONVENTIONS.md")

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
        os.path.dirname(__file__), "templates", "CONVENTIONS.md.tmpl"
    )
    if os.path.isfile(template_path):
        with open(template_path) as f:
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
        safety_rules = extract_safety_rules(install_dir)
        content = content.replace("{{SAFETY_RULES}}", safety_rules)

        # Build agent context references
        agent_refs = build_agent_refs(install_dir)
        content = content.replace("{{AGENT_CONTEXT}}", agent_refs)

        with open(conv_path, "w") as f:
            f.write(content)
    else:
        # Direct generation without template
        safety_rules = extract_safety_rules(install_dir)
        agent_refs = build_agent_refs(install_dir)

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
        with open(conv_path, "w") as f:
            f.write(content)


def generate_ignore(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate .aiderignore from security settings."""
    ignore_path = os.path.join(project_dir, ".aiderignore")

    lines = [
        "# cognitive-core generated .aiderignore",
        "# Prevents Aider from reading sensitive files",
        "",
        "# Secrets and credentials",
        ".env",
        ".env.*",
        "*.pem",
        "*.key",
        "credentials.json",
        "secrets.yaml",
        "secrets.yml",
        "",
        "# Runtime logs",
        ".cognitive-core/cognitive-core/security.log",
        "",
        "# Build artifacts",
        "node_modules/",
        "__pycache__/",
        "*.pyc",
        ".git/",
        "",
        "# IDE and editor files",
        ".idea/",
        ".vscode/",
        "*.swp",
        "*.swo",
    ]

    # Add blocked patterns from config
    blocked = config.get("CC_BLOCKED_PATTERNS", "")
    if blocked:
        lines.append("")
        lines.append("# Project-specific blocked patterns")
        for pattern in blocked.split():
            lines.append(pattern)

    with open(ignore_path, "w") as f:
        f.write("\n".join(lines) + "\n")


def generate_launcher(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate cc-aider-start.sh launcher script."""
    launcher_path = os.path.join(project_dir, "cc-aider-start.sh")

    model = config.get("CC_AIDER_MODEL", "qwen2.5-coder:32b")
    ollama_base = config.get("CC_AIDER_OLLAMA_BASE", "http://localhost:11434")
    project_name = config.get("CC_PROJECT_NAME", "project")
    env_vars = config.get("CC_ENV_VARS", "")

    content = f"""#!/bin/bash
# cognitive-core Aider launcher — {project_name}
# Sets up environment and launches Aider with correct configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load cognitive-core configuration
if [ -f "${{SCRIPT_DIR}}/cognitive-core.conf" ]; then
    # shellcheck disable=SC1091
    source "${{SCRIPT_DIR}}/cognitive-core.conf"
fi

# Set Ollama base URL
export OLLAMA_API_BASE="${{CC_AIDER_OLLAMA_BASE:-{ollama_base}}}"

# Environment variables from config
{_generate_env_exports(env_vars)}

echo "=== cognitive-core Aider launcher ==="
echo "Project:  {project_name}"
echo "Model:    ${{CC_AIDER_MODEL:-{model}}}"
echo "Ollama:   ${{OLLAMA_API_BASE}}"
echo ""

# Launch Aider with project configuration
exec aider "$@"
"""

    with open(launcher_path, "w") as f:
        f.write(content)

    # Make executable
    st = os.stat(launcher_path)
    os.chmod(launcher_path, st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)


def _generate_env_exports(env_vars: str) -> str:
    """Generate export statements from CC_ENV_VARS."""
    if not env_vars.strip():
        return "# No additional environment variables configured"

    exports = []
    for line in env_vars.strip().split("\n"):
        line = line.strip()
        if line and "=" in line:
            exports.append(f"export {line}")

    return "\n".join(exports) if exports else "# No additional environment variables"


def main():
    parser = argparse.ArgumentParser(
        description="Generate Aider configuration from cognitive-core"
    )
    parser.add_argument(
        "--mode",
        required=True,
        choices=["settings", "conventions", "ignore", "launcher", "all"],
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
        "ignore": generate_ignore,
        "launcher": generate_launcher,
    }

    if args.mode == "all":
        for mode, gen_fn in generators.items():
            gen_fn(args.project_dir, args.install_dir, config)
    else:
        generators[args.mode](args.project_dir, args.install_dir, config)


if __name__ == "__main__":
    main()
