#!/bin/bash
# Test suite: Gitignore policy — base template, language packs, merge logic
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/test-helpers.sh"

suite_start "15 — Gitignore Policy"

# ============================================================================
# PART 1: Template file existence and content
# ============================================================================

# ---- Base template ----
assert_file_exists "base template exists" "${ROOT_DIR}/core/templates/gitignore-base"

base_content=$(cat "${ROOT_DIR}/core/templates/gitignore-base")

# OS coverage
assert_contains "base: macOS .DS_Store" "$base_content" ".DS_Store"
assert_contains "base: macOS .Trashes" "$base_content" ".Trashes"
assert_contains "base: macOS .fseventsd" "$base_content" ".fseventsd"
assert_contains "base: Windows Thumbs.db" "$base_content" "Thumbs.db"
assert_contains "base: Windows Desktop.ini" "$base_content" "Desktop.ini"
assert_contains "base: Linux .directory" "$base_content" ".directory"

# Common build output section
assert_contains "base: common build/" "$base_content" "build/"
assert_contains "base: common out/" "$base_content" "out/"
assert_contains "base: common dist/" "$base_content" "dist/"

# IDE coverage — all major IDEs
assert_contains "base: VS Code .vscode/" "$base_content" ".vscode/"
assert_contains "base: VS Code whitelist settings.json" "$base_content" "!.vscode/settings.json"
assert_contains "base: JetBrains .idea/" "$base_content" ".idea/"
assert_contains "base: Eclipse .classpath" "$base_content" ".classpath"
assert_contains "base: Eclipse .settings/" "$base_content" ".settings/"
assert_contains "base: Eclipse STS .sts4-cache/" "$base_content" ".sts4-cache/"
assert_contains "base: NetBeans nbproject/" "$base_content" "nbproject/private/"
assert_contains "base: Visual Studio .vs/" "$base_content" ".vs/"
assert_contains "base: Xcode xcuserdata/" "$base_content" "xcuserdata/"
assert_contains "base: Xcode DerivedData/" "$base_content" "DerivedData/"
assert_contains "base: Android Studio .cxx/" "$base_content" ".cxx/"
assert_contains "base: Sublime Text .sublime-workspace" "$base_content" "*.sublime-workspace"
assert_contains "base: Vim .swp" "$base_content" "*.swp"
assert_contains "base: Emacs backup" "$base_content" "\\#*\\#"
assert_contains "base: TextMate .tmproj" "$base_content" "*.tmproj"
assert_contains "base: Atom .atom/" "$base_content" ".atom/"
assert_contains "base: Notepad++ nppBackup/" "$base_content" "nppBackup/"
assert_contains "base: Kate .kdev4/" "$base_content" ".kdev4/"
assert_contains "base: Fleet .fleet/" "$base_content" ".fleet/"
assert_contains "base: Zed .zed/" "$base_content" ".zed/"
assert_contains "base: Cursor .cursor/" "$base_content" ".cursor/"

# Secrets
assert_contains "base: .env" "$base_content" ".env"
assert_contains "base: whitelist .env.template" "$base_content" "!.env.template"
assert_contains "base: whitelist .env.example" "$base_content" "!.env.example"
assert_contains "base: *.pem" "$base_content" "*.pem"
assert_contains "base: *.jks" "$base_content" "*.jks"
assert_contains "base: *.keystore" "$base_content" "*.keystore"
assert_contains "base: credentials.json" "$base_content" "credentials.json"
assert_contains "base: .htpasswd" "$base_content" ".htpasswd"

# IaC secrets
assert_contains "base: terraform.tfstate" "$base_content" "terraform.tfstate"
assert_contains "base: terraform.tfstate.backup" "$base_content" "terraform.tfstate.backup"
assert_contains "base: .terraform/" "$base_content" ".terraform/"
assert_contains "base: .aws/credentials" "$base_content" ".aws/credentials"
assert_contains "base: .kube/config" "$base_content" ".kube/config"
assert_contains "base: .netrc" "$base_content" ".netrc"
assert_contains "base: vault-token" "$base_content" "vault-token"

# Logs
assert_contains "base: *.log" "$base_content" "*.log"

# Archives
assert_contains "base: *.zip" "$base_content" "*.zip"
assert_contains "base: *.tar.gz" "$base_content" "*.tar.gz"

# cognitive-core runtime
assert_contains "base: version.json ignored" "$base_content" ".claude/cognitive-core/version.json"
assert_contains "base: last-check ignored" "$base_content" ".claude/cognitive-core/last-check"
assert_contains "base: security.log ignored" "$base_content" ".claude/cognitive-core/security.log"

# ---- Language pack existence ----
ALL_LANGS="java spring-boot struts-jsp python node react angular perl go rust csharp"
for lang in $ALL_LANGS; do
    assert_file_exists "lang pack: ${lang}/gitignore exists" \
        "${ROOT_DIR}/language-packs/${lang}/gitignore"
done

# ============================================================================
# PART 2: Language pack content validation
# ============================================================================

java_gi=$(cat "${ROOT_DIR}/language-packs/java/gitignore")
assert_contains "java: *.class" "$java_gi" "*.class"
assert_contains "java: target/" "$java_gi" "target/"
assert_contains "java: Maven wrapper exclusion" "$java_gi" "!gradle/wrapper/gradle-wrapper.jar"
assert_contains "java: hs_err_pid" "$java_gi" "hs_err_pid*"

springboot_gi=$(cat "${ROOT_DIR}/language-packs/spring-boot/gitignore")
assert_contains "spring-boot: application-local" "$springboot_gi" "application-local.properties"
assert_contains "spring-boot: spring-shell.log" "$springboot_gi" "spring-shell.log"

strutsjsp_gi=$(cat "${ROOT_DIR}/language-packs/struts-jsp/gitignore")
assert_contains "struts-jsp: JSP work/" "$strutsjsp_gi" "work/"
assert_contains "struts-jsp: *.class" "$strutsjsp_gi" "*.class"

python_gi=$(cat "${ROOT_DIR}/language-packs/python/gitignore")
assert_contains "python: __pycache__/" "$python_gi" "__pycache__/"
assert_contains "python: *.py[cod]" "$python_gi" '*.py[cod]'
assert_contains "python: .venv/" "$python_gi" ".venv/"
assert_contains "python: .mypy_cache/" "$python_gi" ".mypy_cache/"
assert_contains "python: .ruff_cache/" "$python_gi" ".ruff_cache/"
assert_contains "python: .pytest_cache/" "$python_gi" ".pytest_cache/"
assert_contains "python: PDM __pypackages__/" "$python_gi" "__pypackages__/"
assert_contains "python: uv cache .uv/" "$python_gi" ".uv/"

node_gi=$(cat "${ROOT_DIR}/language-packs/node/gitignore")
assert_contains "node: node_modules/" "$node_gi" "node_modules/"
assert_contains "node: .next/" "$node_gi" ".next/"
assert_contains "node: *.tsbuildinfo" "$node_gi" "*.tsbuildinfo"
assert_contains "node: .turbo/" "$node_gi" ".turbo/"
assert_contains "node: .swc/" "$node_gi" ".swc/"
assert_contains "node: .vercel/" "$node_gi" ".vercel/"

react_gi=$(cat "${ROOT_DIR}/language-packs/react/gitignore")
assert_contains "react: .turbo/" "$react_gi" ".turbo/"
assert_contains "react: .swc/" "$react_gi" ".swc/"

angular_gi=$(cat "${ROOT_DIR}/language-packs/angular/gitignore")
assert_contains "angular: .angular/" "$angular_gi" ".angular/"
assert_contains "angular: .sass-cache/" "$angular_gi" ".sass-cache/"
assert_contains "angular: .turbo/" "$angular_gi" ".turbo/"

perl_gi=$(cat "${ROOT_DIR}/language-packs/perl/gitignore")
assert_contains "perl: blib/" "$perl_gi" "blib/"
assert_contains "perl: cover_db/" "$perl_gi" "cover_db/"
assert_contains "perl: Dist::Zilla .dzil/" "$perl_gi" ".dzil/"

go_gi=$(cat "${ROOT_DIR}/language-packs/go/gitignore")
assert_contains "go: vendor/" "$go_gi" "vendor/"
assert_contains "go: bin/" "$go_gi" "bin/"
assert_contains "go: go.work" "$go_gi" "go.work"

rust_gi=$(cat "${ROOT_DIR}/language-packs/rust/gitignore")
assert_contains "rust: target/" "$rust_gi" "target/"
# Verify Cargo.lock is commented out (not an active ignore rule)
if grep -qx "Cargo.lock" "${ROOT_DIR}/language-packs/rust/gitignore"; then
    _fail "rust: Cargo.lock should NOT be an active rule"
else
    _pass "rust: Cargo.lock is not actively ignored"
fi
assert_contains "rust: Cargo.lock comment guidance" "$rust_gi" "# Cargo.lock"

csharp_gi=$(cat "${ROOT_DIR}/language-packs/csharp/gitignore")
assert_contains "csharp: [Bb]in/" "$csharp_gi" "[Bb]in/"
assert_contains "csharp: [Oo]bj/" "$csharp_gi" "[Oo]bj/"
assert_contains "csharp: NuGet *.nupkg" "$csharp_gi" "*.nupkg"
# Verify no duplication with base (Visual Studio / Rider rules removed)
assert_not_contains "csharp: no *.suo dupe (covered by base)" "$csharp_gi" "*.suo"
assert_not_contains "csharp: no .vs/ dupe (covered by base)" "$csharp_gi" ".vs/"
assert_not_contains "csharp: no .idea/ dupe (covered by base)" "$csharp_gi" ".idea/"

# ============================================================================
# PART 3: Merge function — integration test via install
# ============================================================================

# Create a temp project directory
test_dir=$(create_test_dir)
git -C "$test_dir" init --quiet 2>/dev/null

# Create config for Python project
cat > "${test_dir}/cognitive-core.conf" << 'CONF'
#!/bin/false
CC_PROJECT_NAME="gitignore-test"
CC_PROJECT_DESCRIPTION="Test project for gitignore policy"
CC_ORG="test-org"
CC_LANGUAGE="python"
CC_LINT_EXTENSIONS=".py"
CC_LINT_COMMAND="ruff check $1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="pytest"
CC_TEST_PATTERN="tests/**/*.py"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator"
CC_COORDINATOR_MODEL="sonnet"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume"
CC_HOOKS="setup-env validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES=""
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_SECURITY_LEVEL="standard"
CC_BLOCKED_PATTERNS=""
CC_ALLOWED_DOMAINS=""
CC_KNOWN_SAFE_DOMAINS=""
CC_COMPACT_RULES=""
CC_ENABLE_CLEANUP_CRON="false"
CC_SESSION_DOCS_DIR="docs"
CC_SESSION_MAX_AGE_DAYS="30"
CC_FITNESS_LINT="60"
CC_FITNESS_COMMIT="80"
CC_FITNESS_TEST="85"
CC_FITNESS_MERGE="90"
CC_FITNESS_DEPLOY="95"
CC_RUNNER_NODES="1"
CC_RUNNER_LABELS="self-hosted"
CC_AGENT_TEAMS="false"
CC_MCP_SERVERS=""
CONF

# Run install
install_output=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || {
    _fail "install.sh exited with error"
    echo "$install_output" | tail -20
    rm -rf "$test_dir"
    suite_end || true
    exit 1
}

# Verify .gitignore was created
assert_file_exists "install: .gitignore created" "${test_dir}/.gitignore"

gi_content=$(cat "${test_dir}/.gitignore")

# Base rules merged
assert_contains "merged: .DS_Store from base" "$gi_content" ".DS_Store"
assert_contains "merged: .vscode/ from base" "$gi_content" ".vscode/"
assert_contains "merged: .idea/ from base" "$gi_content" ".idea/"
assert_contains "merged: *.log from base" "$gi_content" "*.log"
assert_contains "merged: terraform.tfstate from base" "$gi_content" "terraform.tfstate"
assert_contains "merged: base section header" "$gi_content" "# ---- base (cognitive-core) ----"

# Python-specific rules merged
assert_contains "merged: __pycache__/ from python" "$gi_content" "__pycache__/"
assert_contains "merged: .venv/ from python" "$gi_content" ".venv/"
assert_contains "merged: .pytest_cache/ from python" "$gi_content" ".pytest_cache/"
assert_contains "merged: python section header" "$gi_content" "# ---- python (cognitive-core) ----"

# cognitive-core runtime
assert_contains "merged: version.json" "$gi_content" ".claude/cognitive-core/version.json"

# ============================================================================
# PART 4: Deduplication — run install again, verify no duplicates
# ============================================================================

# Run install again (simulating update)
install_output2=$(bash "${ROOT_DIR}/install.sh" "$test_dir" 2>&1) || true

gi_content2=$(cat "${test_dir}/.gitignore")

# Count occurrences of .DS_Store — should be exactly 1
ds_count=$(grep -cxF ".DS_Store" "${test_dir}/.gitignore" || echo 0)
assert_eq "dedup: .DS_Store appears exactly once" "1" "$ds_count"

# Count occurrences of __pycache__/ — should be exactly 1
pycache_count=$(grep -cxF "__pycache__/" "${test_dir}/.gitignore" || echo 0)
assert_eq "dedup: __pycache__/ appears exactly once" "1" "$pycache_count"

# Count section headers — should be exactly 1 each
base_header_count=$(grep -cF "# ---- base (cognitive-core) ----" "${test_dir}/.gitignore" || echo 0)
assert_eq "dedup: base section header appears once" "1" "$base_header_count"

python_header_count=$(grep -cF "# ---- python (cognitive-core) ----" "${test_dir}/.gitignore" || echo 0)
assert_eq "dedup: python section header appears once" "1" "$python_header_count"

# ============================================================================
# PART 5: Preserve existing user rules
# ============================================================================

# Create a fresh project with pre-existing .gitignore
test_dir2=$(create_test_dir)
git -C "$test_dir2" init --quiet 2>/dev/null

# Add user-specific rules
cat > "${test_dir2}/.gitignore" << 'USERGI'
# My custom rules
my-local-config/
*.sqlite3
data/exports/
USERGI

cp "${test_dir}/cognitive-core.conf" "${test_dir2}/cognitive-core.conf"

# Run install
bash "${ROOT_DIR}/install.sh" "$test_dir2" 2>&1 >/dev/null || true

gi_content3=$(cat "${test_dir2}/.gitignore")

# User rules preserved
assert_contains "preserve: user rule my-local-config/" "$gi_content3" "my-local-config/"
assert_contains "preserve: user rule *.sqlite3" "$gi_content3" "*.sqlite3"
assert_contains "preserve: user rule data/exports/" "$gi_content3" "data/exports/"
assert_contains "preserve: user comment preserved" "$gi_content3" "# My custom rules"

# Framework rules also added
assert_contains "preserve: base rules also added" "$gi_content3" ".DS_Store"
assert_contains "preserve: python rules also added" "$gi_content3" "__pycache__/"

# ============================================================================
# PART 6: Different language pack — verify correct pack applied
# ============================================================================

test_dir3=$(create_test_dir)
git -C "$test_dir3" init --quiet 2>/dev/null

# Config for Java project
cat > "${test_dir3}/cognitive-core.conf" << 'JAVACONF'
#!/bin/false
CC_PROJECT_NAME="java-test"
CC_PROJECT_DESCRIPTION="Test"
CC_ORG="test-org"
CC_LANGUAGE="java"
CC_LINT_EXTENSIONS=".java"
CC_LINT_COMMAND="checkstyle $1"
CC_FORMAT_COMMAND=""
CC_TEST_COMMAND="mvn test"
CC_TEST_PATTERN="src/test/**/*.java"
CC_DATABASE="none"
CC_ARCHITECTURE="ddd"
CC_SRC_ROOT="src"
CC_TEST_ROOT="tests"
CC_AGENTS="coordinator"
CC_COORDINATOR_MODEL="sonnet"
CC_SPECIALIST_MODEL="sonnet"
CC_SKILLS="session-resume"
CC_HOOKS="setup-env validate-bash"
CC_MAIN_BRANCH="main"
CC_COMMIT_FORMAT="conventional"
CC_COMMIT_SCOPES=""
CC_ENABLE_CICD="false"
CC_RUNNER_TYPE="github-hosted"
CC_MONITORING="false"
CC_SECURITY_LEVEL="standard"
CC_BLOCKED_PATTERNS=""
CC_ALLOWED_DOMAINS=""
CC_KNOWN_SAFE_DOMAINS=""
CC_COMPACT_RULES=""
CC_ENABLE_CLEANUP_CRON="false"
CC_SESSION_DOCS_DIR="docs"
CC_SESSION_MAX_AGE_DAYS="30"
CC_FITNESS_LINT="60"
CC_FITNESS_COMMIT="80"
CC_FITNESS_TEST="85"
CC_FITNESS_MERGE="90"
CC_FITNESS_DEPLOY="95"
CC_RUNNER_NODES="1"
CC_RUNNER_LABELS="self-hosted"
CC_AGENT_TEAMS="false"
CC_MCP_SERVERS=""
JAVACONF

bash "${ROOT_DIR}/install.sh" "$test_dir3" 2>&1 >/dev/null || true

gi_java=$(cat "${test_dir3}/.gitignore")

# Java-specific rules present
assert_contains "java install: *.class" "$gi_java" "*.class"
assert_contains "java install: target/" "$gi_java" "target/"
assert_contains "java install: java section header" "$gi_java" "# ---- java (cognitive-core) ----"

# Python-specific rules NOT present
assert_not_contains "java install: no __pycache__" "$gi_java" "__pycache__/"
assert_not_contains "java install: no .venv/" "$gi_java" ".venv/"
assert_not_contains "java install: no python section" "$gi_java" "# ---- python (cognitive-core) ----"

# ============================================================================
# PART 7: struts-jsp in install menu
# ============================================================================

# Verify struts-jsp is in the language prompt options in install.sh
if grep -qF "struts-jsp" "${ROOT_DIR}/install.sh"; then
    _pass "struts-jsp: in language menu"
else
    _fail "struts-jsp: in language menu"
fi
if grep -qF 'struts-jsp)' "${ROOT_DIR}/install.sh"; then
    _pass "struts-jsp: has case branch"
else
    _fail "struts-jsp: has case branch"
fi

# ============================================================================
# PART 8: build/ and out/ not under IDE sections
# ============================================================================

# Verify build/ appears before IDE sections (in common build output section)
# Extract line numbers
build_line=$(grep -n "^build/" "${ROOT_DIR}/core/templates/gitignore-base" | head -1 | cut -d: -f1)
xcode_line=$(grep -n "# Xcode" "${ROOT_DIR}/core/templates/gitignore-base" | head -1 | cut -d: -f1)
jetbrains_line=$(grep -n "# JetBrains" "${ROOT_DIR}/core/templates/gitignore-base" | head -1 | cut -d: -f1)

if [ -n "$build_line" ] && [ -n "$xcode_line" ] && [ "$build_line" -lt "$xcode_line" ]; then
    _pass "structure: build/ appears before Xcode section"
else
    _fail "structure: build/ should appear before Xcode section" "build=$build_line xcode=$xcode_line"
fi

if [ -n "$build_line" ] && [ -n "$jetbrains_line" ] && [ "$build_line" -lt "$jetbrains_line" ]; then
    _pass "structure: build/ appears before JetBrains section"
else
    _fail "structure: build/ should appear before JetBrains section" "build=$build_line jetbrains=$jetbrains_line"
fi

# Verify out/ is NOT under JetBrains anymore
jetbrains_block=$(sed -n '/# JetBrains/,/^$/p' "${ROOT_DIR}/core/templates/gitignore-base")
if ! echo "$jetbrains_block" | grep -qxF "out/"; then
    _pass "structure: out/ not nested under JetBrains"
else
    _fail "structure: out/ should not be under JetBrains section"
fi

# ============================================================================
# Cleanup
# ============================================================================

rm -rf "$test_dir" "$test_dir2" "$test_dir3"

suite_end
