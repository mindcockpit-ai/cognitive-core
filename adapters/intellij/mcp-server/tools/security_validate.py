"""
Security validation for bash commands.

Ports the safety patterns from cognitive-core's validate-bash.sh hook to Python.
Returns allow/deny decisions matching the hook protocol.
"""
import re


# Built-in safety patterns (always active)
BUILTIN_PATTERNS = [
    # rm targeting system-critical paths
    (
        r'rm\s+(-[a-z]*f[a-z]*\s+)?(/|/etc|/usr|/var|/home|/System|/Library)(\s|$)',
        "rm targeting system-critical path",
    ),
    # git push --force to main/master
    (
        r'git\s+push\s+.*--force.*\s+(master|main)(\s|$)|'
        r'git\s+push\s+.*-f\s+.*(master|main)(\s|$)',
        "force push to main/master",
    ),
    # git reset --hard
    (r'git\s+reset\s+--hard', "git reset --hard (destructive, may lose work)"),
    # DROP TABLE / TRUNCATE TABLE
    (r'(drop|truncate)\s+table', "DROP/TRUNCATE TABLE (destructive database operation)"),
    # DELETE FROM without WHERE
    (
        r'delete\s+from\s+[a-zA-Z0-9_]+\s*$|delete\s+from\s+[a-zA-Z0-9_]+\s*;',
        "DELETE FROM without WHERE clause",
    ),
    # rm .git
    (r'rm\s+(-[a-z]*\s+)?\.git(\s|$|/)', "removing .git directory"),
    # chmod 777
    (r'chmod\s+777', "chmod 777 (insecure permissions)"),
    # git clean -f (without dry-run)
    # Note: checked separately due to negative lookahead logic
]

# Standard level patterns (exfiltration, encoded commands, pipe-to-shell)
STANDARD_PATTERNS = [
    # Exfiltration
    (r'curl\s+.*-d\s+.*@', "potential data exfiltration (curl -d @file)"),
    (r'cat\s+.*\|.*curl', "potential data exfiltration (cat | curl)"),
    (r'cat\s+.*\|.*(\s|^)nc(\s|$)', "potential data exfiltration (cat | nc)"),
    (r'(^|\s)env\s*\|', "environment variable leak (env |)"),
    # Encoded command bypass
    (r'base64.*-d.*\|.*(ba)?sh', "encoded command execution (base64 -d | sh)"),
    (r'echo\s+.*\|.*base64.*-d', "encoded command execution (echo | base64 -d)"),
    (r'(^|\s)eval\s+.*\$\(', "eval with command substitution"),
    # Pipe-to-shell
    (r'curl\s+.*\|.*(ba)?sh', "pipe-to-shell (curl | sh) — supply chain risk"),
    (r'wget\s+.*\|.*(ba)?sh', "pipe-to-shell (wget | sh) — supply chain risk"),
    (r'wget\s+.*-O-\s*\|', "pipe-to-shell (wget -O- |) — supply chain risk"),
]


def validate_command(
    command: str,
    security_level: str = "standard",
    blocked_patterns: list | None = None,
) -> dict:
    """
    Validate a bash command against cognitive-core safety rules.

    Args:
        command: The bash command to validate.
        security_level: One of "minimal", "standard", "strict". Default "standard".
        blocked_patterns: Additional regex patterns to block.

    Returns:
        dict with keys:
            decision: "allow" or "deny"
            reason: Human-readable reason
    """
    if not command or not command.strip():
        return {"decision": "allow", "reason": "Empty command"}

    cmd_lower = command.lower()

    # Check built-in patterns
    for pattern, reason in BUILTIN_PATTERNS:
        if re.search(pattern, cmd_lower):
            return {"decision": "deny", "reason": f"Blocked: {reason}"}

    # git clean -f without -n (special two-step check)
    if re.search(r'git\s+clean\s+-[a-z]*f', cmd_lower):
        if not re.search(r'git\s+clean\s+-[a-z]*n', cmd_lower):
            return {
                "decision": "deny",
                "reason": "Blocked: git clean -f (removes untracked files)",
            }

    # Standard level patterns
    if security_level != "minimal":
        for pattern, reason in STANDARD_PATTERNS:
            if re.search(pattern, cmd_lower):
                return {"decision": "deny", "reason": f"Blocked: {reason}"}

    # Project-specific blocked patterns
    if blocked_patterns:
        for pattern in blocked_patterns:
            try:
                if re.search(pattern, cmd_lower):
                    return {
                        "decision": "deny",
                        "reason": f"Blocked: matches project safety rule: {pattern}",
                    }
            except re.error:
                continue

    return {"decision": "allow", "reason": "Command passes safety validation"}
