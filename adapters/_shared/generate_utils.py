"""Shared utilities for cognitive-core adapter Python generators.

Extracted from aider/intellij/vscode generate.py to eliminate DRY violations (#139 P3).
All adapters import these instead of duplicating the implementations.
"""

from __future__ import annotations

import re
import shlex
import subprocess
from pathlib import Path


def load_config(config_file: str) -> dict[str, str]:
    """Load cognitive-core.conf by sourcing it in bash and capturing variables."""
    if not config_file or not Path(config_file).is_file():
        return {}

    cmd = f'set -a; source {shlex.quote(config_file)} 2>/dev/null; env | grep "^CC_"'
    try:
        result = subprocess.run(
            ["bash", "-c", cmd], capture_output=True, text=True, timeout=5
        )
        config: dict[str, str] = {}
        for line in result.stdout.strip().split("\n"):
            if "=" in line:
                key, _, value = line.partition("=")
                config[key] = value
        return config
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {}


def extract_safety_rules(install_dir: str) -> str:
    """Extract safety rules from validate-bash.sh hook.

    Falls back to safety-rules.txt, then hardcoded defaults.
    """
    hook_path = Path(install_dir) / "hooks" / "validate-bash.sh"
    if hook_path.is_file():
        try:
            content = hook_path.read_text(encoding="utf-8")
            reason_pattern = re.compile(r'REASON="Blocked:\s*(.+?)"')
            rules = [
                f"- NEVER: {m.group(1).strip()}"
                for m in reason_pattern.finditer(content)
            ]
            if rules:
                return "\n".join(rules)
        except (OSError, UnicodeDecodeError):
            pass

    return _default_safety_rules(install_dir)


def _default_safety_rules(install_dir: str = "") -> str:
    """Default safety rules from safety-rules.txt or hardcoded fallback."""
    # Try the single-source-of-truth file first
    if install_dir:
        rules_file = Path(install_dir).parent / "_shared" / "safety-rules.txt"
        if rules_file.is_file():
            try:
                lines = rules_file.read_text(encoding="utf-8").strip().splitlines()
                return "\n".join(f"- {line}" for line in lines if line.strip())
            except OSError:
                pass

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


def build_agent_refs(install_dir: str) -> str:
    """Build agent context reference section."""
    agents_dir = Path(install_dir) / "agents"
    if not agents_dir.is_dir():
        return "No agent documentation installed."

    refs: list[str] = []
    for agent_file in sorted(agents_dir.iterdir()):
        if agent_file.suffix == ".md":
            name = agent_file.stem.replace("-", " ").title()
            rel_path = Path(".cognitive-core") / "agents" / agent_file.name
            refs.append(f"- **{name}**: `{rel_path}`")

    if not refs:
        return "No agent documentation installed."

    return (
        "Agent documentation is available for reference:\n"
        + "\n".join(refs)
        + "\n\nUse their guidance when working in their specialist domains."
    )
