#!/bin/bash
# cognitive-core language pack: Python lint integration
# Configures ruff and mypy for the project
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring Python lint tools for: $PROJECT_DIR"

# Create ruff.toml if not present
if [ ! -f "$PROJECT_DIR/ruff.toml" ] && [ ! -f "$PROJECT_DIR/pyproject.toml" ]; then
    cat > "$PROJECT_DIR/ruff.toml" << 'RUFF'
# cognitive-core default ruff configuration — Python 3.12+
target-version = "py312"
line-length = 100

[lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade (modernize syntax)
    "B",    # flake8-bugbear
    "SIM",  # flake8-simplify
    "TCH",  # flake8-type-checking
    "RUF",  # ruff-specific rules
    "ASYNC",# flake8-async (async anti-patterns)
    "S",    # flake8-bandit (security)
    "DTZ",  # flake8-datetimez (timezone-aware datetimes)
    "PT",   # flake8-pytest-style
    "PERF", # perflint (performance anti-patterns)
    "FURB", # refurb (modernize)
]
ignore = [
    "E501",  # line too long (handled by formatter)
    "S101",  # assert used (OK in tests)
]

[lint.isort]
known-first-party = ["src"]

[lint.per-file-ignores]
"tests/**/*.py" = ["S101", "S106"]

[format]
quote-style = "double"
indent-style = "space"
RUFF
    echo "  Created ruff.toml (Python 3.12+)"
else
    echo "  ruff.toml or pyproject.toml already exists, skipping"
fi

# Create mypy.ini if not present
if [ ! -f "$PROJECT_DIR/mypy.ini" ] && ! grep -q '\[tool.mypy\]' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    cat > "$PROJECT_DIR/mypy.ini" << 'MYPY'
[mypy]
python_version = 3.12
warn_return_any = True
warn_unused_configs = True
disallow_untyped_defs = True
check_untyped_defs = True
ignore_missing_imports = True
strict_equality = True
warn_redundant_casts = True
warn_unused_ignores = True
show_error_codes = True

[mypy-tests.*]
disallow_untyped_defs = False
MYPY
    echo "  Created mypy.ini (Python 3.12)"
else
    echo "  mypy config already exists, skipping"
fi

echo "Python lint configuration complete."
