#!/usr/bin/env python3
"""
cognitive-core VS Code configuration generator.

Translates cognitive-core configuration into VS Code-compatible files:
  --mode settings      -> .vscode/mcp.json
  --mode instructions  -> .github/copilot-instructions.md
  --mode mcp-config    -> MCP server configuration snippet
  --mode all           -> all of the above

Usage:
  python3 generate.py --mode all --project-dir /path/to/project \
      --install-dir /path/to/project/.cognitive-core \
      --config-file /path/to/project/cognitive-core.conf
"""
import argparse
import json
import os
import sys
from pathlib import Path

# Shared utilities — single source of truth (#139 P3)
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from _shared.generate_utils import load_config, extract_safety_rules, build_agent_refs


def generate_settings(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate .vscode/mcp.json with cognitive-core MCP server registration."""
    vscode_dir = Path(project_dir) / ".vscode"
    vscode_dir.mkdir(parents=True, exist_ok=True)
    settings_path = vscode_dir / "mcp.json"

    mcp_config = {
        "servers": {
            "cognitive-core": {
                "type": "stdio",
                "command": "python3",
                "args": [
                    ".cognitive-core/mcp-server/server.py"
                ],
                "env": {
                    "CC_PROJECT_DIR": ".",
                    "CC_INSTALL_DIR": ".cognitive-core",
                },
            }
        }
    }

    with open(settings_path, "w", encoding="utf-8") as f:
        json.dump(mcp_config, f, indent=2)
        f.write("\n")


def generate_instructions(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate .github/copilot-instructions.md from config, safety rules, and template."""
    github_dir = Path(project_dir) / ".github"
    github_dir.mkdir(parents=True, exist_ok=True)
    instructions_path = github_dir / "copilot-instructions.md"

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
    template_path = Path(__file__).parent / "templates" / "copilot-instructions.md.tmpl"
    if template_path.is_file():
        content = template_path.read_text(encoding="utf-8")

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

        instructions_path.write_text(content, encoding="utf-8")
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
        instructions_path.write_text(content, encoding="utf-8")



# _extract_safety_rules, _default_safety_rules, _build_agent_refs
# moved to adapters/_shared/generate_utils.py (#139 P3)


def generate_mcp_config(project_dir: str, install_dir: str, config: dict) -> None:
    """Generate MCP server configuration snippet for IDE extensions."""
    mcp_config_path = Path(install_dir) / "mcp-config.json"
    project_name = config.get("CC_PROJECT_NAME", "project")

    mcp_config = {
        "mcpServers": {
            "cognitive-core": {
                "command": "python3",
                "args": [
                    str(Path(install_dir) / "mcp-server" / "server.py")
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


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate VS Code configuration from cognitive-core"
    )
    parser.add_argument(
        "--mode",
        required=True,
        choices=["settings", "instructions", "mcp-config", "all"],
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

    generators: dict[str, callable] = {
        "settings": generate_settings,
        "instructions": generate_instructions,
        "mcp-config": generate_mcp_config,
    }

    if args.mode == "all":
        for mode, gen_fn in generators.items():
            gen_fn(args.project_dir, args.install_dir, config)
    else:
        generators[args.mode](args.project_dir, args.install_dir, config)


if __name__ == "__main__":
    main()
