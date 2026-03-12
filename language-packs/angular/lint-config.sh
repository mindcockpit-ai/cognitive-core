#!/bin/bash
# cognitive-core language pack: Angular lint integration
# Configures ESLint 9 flat config with @angular-eslint, Prettier, and TypeScript strict mode
set -euo pipefail

PROJECT_DIR="${1:-.}"

echo "Configuring Angular lint tools for: $PROJECT_DIR"

# --- ESLint 9 flat config with @angular-eslint ---
if [ ! -f "$PROJECT_DIR/eslint.config.js" ] && \
   [ ! -f "$PROJECT_DIR/eslint.config.mjs" ] && \
   [ ! -f "$PROJECT_DIR/eslint.config.ts" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.json" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.js" ] && \
   [ ! -f "$PROJECT_DIR/.eslintrc.yml" ]; then
    cat > "$PROJECT_DIR/eslint.config.mjs" << 'ESLINT'
import js from "@eslint/js";
import tseslint from "typescript-eslint";
import angular from "angular-eslint";

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
    files: ["**/*.ts"],
    extends: [
      ...angular.configs.tsRecommended,
    ],
    processor: angular.processInlineTemplates,
    rules: {
      "@angular-eslint/component-selector": ["error", {
        type: "element",
        prefix: "app",
        style: "kebab-case",
      }],
      "@angular-eslint/directive-selector": ["error", {
        type: "attribute",
        prefix: "app",
        style: "camelCase",
      }],
      "@angular-eslint/prefer-standalone": "error",
      "@angular-eslint/prefer-on-push-component-change-detection": "warn",
      "@typescript-eslint/no-explicit-any": "error",
      "@typescript-eslint/no-unused-vars": ["error", { argsIgnorePattern: "^_" }],
      "no-console": "warn",
      "prefer-const": "error",
      "no-var": "error",
      eqeqeq: "error",
    },
  },
  {
    files: ["**/*.html"],
    extends: [
      ...angular.configs.templateRecommended,
      ...angular.configs.templateAccessibility,
    ],
  },
  {
    ignores: ["dist/", "node_modules/", "coverage/", ".angular/", "*.config.*"],
  }
);
ESLINT
    echo "  Created eslint.config.mjs (ESLint 9 flat config with @angular-eslint)"
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
  "bracketSpacing": true,
  "htmlWhitespaceSensitivity": "ignore"
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
  "compileOnSave": false,
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ES2022",
    "moduleResolution": "bundler",
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
      "@app/*": ["./src/app/*"],
      "@env/*": ["./src/environments/*"]
    }
  },
  "angularCompilerOptions": {
    "strictInjectionParameters": true,
    "strictInputAccessModifiers": true,
    "strictTemplates": true
  }
}
TSCONFIG
    echo "  Created tsconfig.json (strict mode + Angular compiler options)"
else
    echo "  tsconfig.json already exists, skipping"
fi

echo "Angular lint configuration complete."
