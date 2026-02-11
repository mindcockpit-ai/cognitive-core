#!/bin/bash
# cognitive-core language pack: Python lint integration
# Configures ruff and mypy for the project
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring Python lint tools for: $PROJECT_DIR"

# Create ruff.toml if not present
if [ ! -f "$PROJECT_DIR/ruff.toml" ] && [ ! -f "$PROJECT_DIR/pyproject.toml" ]; then
    cat > "$PROJECT_DIR/ruff.toml" << 'RUFF'
# cognitive-core default ruff configuration
target-version = "py311"
line-length = 100

[lint]
select = [
    "E",    # pycodestyle errors
    "W",    # pycodestyle warnings
    "F",    # pyflakes
    "I",    # isort
    "N",    # pep8-naming
    "UP",   # pyupgrade
    "B",    # flake8-bugbear
    "SIM",  # flake8-simplify
    "TCH",  # flake8-type-checking
    "RUF",  # ruff-specific rules
]
ignore = [
    "E501",  # line too long (handled by formatter)
]

[lint.isort]
known-first-party = ["src"]

[format]
quote-style = "double"
indent-style = "space"
RUFF
    echo "  Created ruff.toml"
else
    echo "  ruff.toml or pyproject.toml already exists, skipping"
fi

# Create mypy.ini if not present
if [ ! -f "$PROJECT_DIR/mypy.ini" ] && ! grep -q '\[tool.mypy\]' "$PROJECT_DIR/pyproject.toml" 2>/dev/null; then
    cat > "$PROJECT_DIR/mypy.ini" << 'MYPY'
[mypy]
python_version = 3.11
warn_return_any = True
warn_unused_configs = True
disallow_untyped_defs = True
check_untyped_defs = True
ignore_missing_imports = True
MYPY
    echo "  Created mypy.ini"
else
    echo "  mypy config already exists, skipping"
fi

echo "Python lint configuration complete."
