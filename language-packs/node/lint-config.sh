#!/bin/bash
# cognitive-core language pack: Node.js lint integration
# Configures eslint and prettier for the project
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring Node.js lint tools for: $PROJECT_DIR"

# Create .eslintrc.json if not present and no eslint config exists
if [ ! -f "$PROJECT_DIR/.eslintrc.json" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.js" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.yml" ] && \
   [ ! -f "$PROJECT_DIR/eslint.config.js" ] && \
   [ ! -f "$PROJECT_DIR/eslint.config.mjs" ]; then
    cat > "$PROJECT_DIR/.eslintrc.json" << 'ESLINT'
{
  "env": {
    "node": true,
    "es2022": true,
    "jest": true
  },
  "extends": [
    "eslint:recommended"
  ],
  "parserOptions": {
    "ecmaVersion": "latest",
    "sourceType": "module"
  },
  "rules": {
    "no-unused-vars": ["warn", { "argsIgnorePattern": "^_" }],
    "no-console": "warn",
    "prefer-const": "error",
    "no-var": "error",
    "eqeqeq": "error",
    "curly": "error"
  }
}
ESLINT
    echo "  Created .eslintrc.json"
else
    echo "  ESLint config already exists, skipping"
fi

# Create .prettierrc if not present
if [ ! -f "$PROJECT_DIR/.prettierrc" ] && \
   [ ! -f "$PROJECT_DIR/.prettierrc.json" ] && \
   [ ! -f "$PROJECT_DIR/prettier.config.js" ]; then
    cat > "$PROJECT_DIR/.prettierrc" << 'PRETTIER'
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2,
  "arrowParens": "always"
}
PRETTIER
    echo "  Created .prettierrc"
else
    echo "  Prettier config already exists, skipping"
fi

echo "Node.js lint configuration complete."
