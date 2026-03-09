#!/bin/bash
# cognitive-core language pack: React/TypeScript lint integration
# Configures ESLint 9 flat config, Prettier, and TypeScript strict mode
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring React/TypeScript lint tools for: $PROJECT_DIR"

# --- ESLint 9 flat config ---
if [ ! -f "$PROJECT_DIR/eslint.config.js" ] && \
   [ ! -f "$PROJECT_DIR/eslint.config.mjs" ] && \
   [ ! -f "$PROJECT_DIR/eslint.config.ts" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.json" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.js" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.yml" ]; then
    cat > "$PROJECT_DIR/eslint.config.mjs" << 'ESLINT'
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import react from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import jsxA11y from "eslint-plugin-jsx-a11y";

export default tseslint.config(
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
  {
    files: ["**/*.{ts,tsx}"],
    plugins: {
      react,
      "react-hooks": reactHooks,
      "jsx-a11y": jsxA11y,
    },
    rules: {
      ...react.configs.recommended.rules,
      ...react.configs["jsx-runtime"].rules,
      ...reactHooks.configs.recommended.rules,
      ...jsxA11y.configs.recommended.rules,
      "react/prop-types": "off",
      "react-hooks/exhaustive-deps": "error",
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-console": "warn",
      "prefer-const": "error",
      "no-var": "error",
      eqeqeq: "error",
    },
    settings: {
      react: { version: "detect" },
    },
  },
  {
    ignores: ["dist/", "build/", "node_modules/", "coverage/", "*.config.*"],
  }
);
ESLINT
    echo "  Created eslint.config.mjs (ESLint 9 flat config)"
else
    echo "  ESLint config already exists, skipping"
fi

# --- Prettier ---
if [ ! -f "$PROJECT_DIR/.prettierrc" ] && \
   [ ! -f "$PROJECT_DIR/.prettierrc.json" ] && \
   [ ! -f "$PROJECT_DIR/prettier.config.js" ] && \
   [ ! -f "$PROJECT_DIR/prettier.config.mjs" ]; then
    cat > "$PROJECT_DIR/.prettierrc" << 'PRETTIER'
{
  "semi": true,
  "singleQuote": true,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2,
  "arrowParens": "always",
  "jsxSingleQuote": false,
  "bracketSpacing": true,
  "bracketSameLine": false
}
PRETTIER
    echo "  Created .prettierrc"
else
    echo "  Prettier config already exists, skipping"
fi

# --- TypeScript strict config ---
if [ ! -f "$PROJECT_DIR/tsconfig.json" ]; then
    cat > "$PROJECT_DIR/tsconfig.json" << 'TSCONFIG'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "jsx": "react-jsx",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noFallthroughCasesInSwitch": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist", "build"]
}
TSCONFIG
    echo "  Created tsconfig.json (strict mode)"
else
    echo "  tsconfig.json already exists, skipping"
fi

echo "React/TypeScript lint configuration complete."
