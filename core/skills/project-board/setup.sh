#!/bin/bash
# =============================================================================
# project-board setup
#
# Usage:
#   ./setup.sh --check                       Check the configured board against the live one
#   ./setup.sh --sync [owner repo number]    Create missing labels, write live IDs to the conf, check
#   ./setup.sh <owner> <repo> [project-name] Create a new GitHub Project with the standard structure
#
# --check / --sync exit: 0 clean, 1 findings, 2 backend failure (gh), 3 not supported by the provider
# Requires: gh CLI with project scope authenticated
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()  { printf "${GREEN}[+]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${RESET} %s\n" "$*"; }
err()   { printf "${RED}[x]${RESET} %s\n" "$*" >&2; }
header(){ printf "\n${BOLD}${CYAN}=== %s ===${RESET}\n" "$*"; }

# Standard labels: name|color|description
labels() {
    cat <<'LABELS'
priority:p0-critical|B60205|Critical priority
priority:p1-high|D93F0B|High priority
priority:p2-medium|FBCA04|Medium priority
priority:p3-low|0E8A16|Low priority
area:cicd|1D76DB|CI/CD pipeline
area:monitoring|7057FF|Monitoring and alerting
area:testing|FFDD57|Testing framework
area:security|E11D48|Security
area:infrastructure|F9A825|Infrastructure
approved|0075CA|Closure approved by reviewer
blocked|B60205|Blocked by impediment
LABELS
}

# ---- Existing project: --check / --sync ----

conf_file() {
    local dir="${PROJECT_DIR:-.}" c
    for c in "${dir}/cognitive-core.conf" "${dir}/.claude/cognitive-core.conf"; do
        [ -f "$c" ] && { echo "$c"; return 0; }
    done
    return 1
}

# Conf value, read in a subshell (the conf is shell code)
conf_get() { # <conf> <var>
    (
        set +eu
        # shellcheck source=/dev/null
        source "$1" >/dev/null 2>&1
        CC_PROJECT_BOARD_PROVIDER="${CC_PROJECT_BOARD_PROVIDER:-${CC_BOARD_PROVIDER:-}}"
        printf '%s' "${!2:-}"
    )
}

# Prints the check JSON; returns the provider's exit code
run_check() { # <conf>
    local provider
    provider=$(conf_get "$1" CC_PROJECT_BOARD_PROVIDER)
    PROJECT_DIR="${PROJECT_DIR:-.}" "$BASH" "${SCRIPT_DIR}/providers/${provider:-github}.sh" provider check
}

# Check JSON for exit 0/1; anything else ends the run. A config error exits 1 without a report.
checked() { # <rc> <json>
    [ "$1" -le 1 ] || exit "$1"
    python3 -c 'import json,sys; assert "findings" in json.loads(sys.argv[1])' "$2" 2>/dev/null || {
        err "Board check did not run (see the error above)"
        exit 1
    }
}

render() { # <check json>
    python3 -c '
import json, sys
data = json.loads(sys.argv[1])
for f in data["findings"]:
    extra = ""
    if f["conf"] or f["live"]:
        extra = " (conf: %s, board: %s)" % (f["conf"] or "-", f["live"] or "-")
    print("  [%s] %s: %s%s" % (f["level"], f["key"], f["message"], extra))
print("Board check: %s" % ("OK" if data["ok"] else "findings"))
' "$1"
}

# Set KEY="value" in the conf: an existing KEY= line (also indented or with export) is replaced
# in place, further ones dropped, missing keys appended. Values are restricted to safe
# characters (the conf is sourced). A symlink's target is updated; mode and a .bak are kept;
# an unchanged conf is not written.
write_conf() { # <conf> KEY=value...
    local conf="$1" pair real tmp
    shift
    for pair in "$@"; do
        if [[ ! "${pair#*=}" =~ ^[A-Za-z0-9_./-]+$ ]]; then
            err "Refusing to write ${pair%%=*}: unsafe value '${pair#*=}'"
            return 1
        fi
    done
    real=$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$conf") || return 1
    tmp="${real}.sync.$$"
    cp -p "$real" "$tmp" || { err "Cannot write next to $real"; return 1; }
    if ! PAIRS="$(printf '%s\n' "$@")" awk '
        BEGIN {
            n = split(ENVIRON["PAIRS"], p, "\n")
            for (i = 1; i <= n; i++) {
                if (p[i] == "") continue
                k = substr(p[i], 1, index(p[i], "=") - 1)
                val[k] = substr(p[i], index(p[i], "=") + 1); order[++m] = k
            }
        }
        {
            for (k in val) if ($0 ~ ("^[ \t]*(export[ \t]+)?" k "=")) {
                if (!(k in done)) { print k "=\"" val[k] "\""; done[k] = 1 }
                next
            }
            print
        }
        END {
            for (i = 1; i <= m; i++) if (!(order[i] in done)) {
                if (!hdr) { print ""; print "# project-board (setup.sh --sync)"; hdr = 1 }
                print order[i] "=\"" val[order[i]] "\""
            }
        }' "$real" > "$tmp"; then
        rm -f "$tmp"
        err "Cannot rewrite $real"
        return 1
    fi
    # Unchanged (awk only adds a missing final newline): leave the conf alone
    if cmp -s "$tmp" "$real" || { [ -n "$(tail -c1 "$real")" ] && { cat "$real"; echo; } | cmp -s "$tmp" -; }; then
        rm -f "$tmp"
        return 0
    fi
    cp -p "$real" "${real}.bak" && mv "$tmp" "$real" || {
        rm -f "$tmp"
        err "Cannot replace $real"
        return 1
    }
    info "Updated $real (backup: ${real}.bak)"
}

cmd_check() {
    local conf json rc=0
    conf=$(conf_file) || { err "cognitive-core.conf not found"; exit 1; }
    json=$(run_check "$conf") || rc=$?
    checked "$rc" "$json"
    render "$json"
    exit "$rc"
}

cmd_sync() {
    local conf json rc=0 repo
    if [ $# -ne 0 ] && [ $# -ne 3 ]; then
        err "Usage: setup.sh --sync [owner repo number]"
        exit 1
    fi
    conf=$(conf_file) || { err "cognitive-core.conf not found"; exit 1; }
    # The board address first, so the check below reads that board
    if [ $# -eq 3 ]; then
        write_conf "$conf" "CC_GITHUB_OWNER=$1" "CC_GITHUB_REPO=$1/$2" "CC_PROJECT_NUMBER=$3" || exit 1
    fi
    json=$(run_check "$conf") || rc=$?
    checked "$rc" "$json"
    repo=$(conf_get "$conf" CC_GITHUB_REPO)

    # Missing labels
    local missing label color desc
    missing=$(python3 -c 'import json,sys; print("\n".join(f["key"][6:] for f in json.loads(sys.argv[1])["findings"] if f["key"].startswith("label:")))' "$json")
    while IFS='|' read -r label color desc; do
        if grep -qxF "$label" <<< "$missing"; then
            gh label create "$label" --repo "$repo" --color "$color" --description "$desc" >/dev/null || exit 2
            info "Created label: $label"
        fi
    done < <(labels)

    # Live IDs into the conf
    local -a pairs=()
    while IFS= read -r pair; do
        [ -n "$pair" ] && pairs+=("$pair")
    done < <(python3 -c '
import json, sys
live = json.loads(sys.argv[1])["live"]
if live["project_id"]: print("CC_PROJECT_ID=" + live["project_id"])
if live["status_field_id"]: print("CC_STATUS_FIELD_ID=" + live["status_field_id"])
for key, oid in live["options"].items(): print("CC_STATUS_%s_ID=%s" % (key.upper(), oid))
' "$json")
    write_conf "$conf" ${pairs[@]+"${pairs[@]}"} || exit 1

    rc=0
    json=$(run_check "$conf") || rc=$?
    checked "$rc" "$json"
    render "$json"
    exit "$rc"
}

usage() { sed -n '4,10p' "$0" | sed 's/^# \{0,1\}//'; }

case "${1:-}" in
    --check) cmd_check ;;
    --sync)  shift; cmd_sync "$@" ;;
    -h|--help) usage; exit 0 ;;
    ""|-*) usage >&2; exit 1 ;;
esac

# ---- New project ----
OWNER="${1:?Usage: setup.sh <owner> <repo> [project-name]}"
REPO="${2:?Usage: setup.sh <owner> <repo> [project-name]}"
PROJECT_NAME="${3:-${REPO} Development}"

header "Project Board Setup"
info "Owner: ${OWNER}"
info "Repo: ${OWNER}/${REPO}"
info "Project: ${PROJECT_NAME}"

# ---- Check gh auth ----
if ! gh auth status &>/dev/null; then
    err "GitHub CLI not authenticated. Run: gh auth login"
    exit 1
fi

# Check project scope
if ! gh project list --owner "$OWNER" &>/dev/null 2>&1; then
    warn "Missing project scope. Running: gh auth refresh -h github.com -s project"
    gh auth refresh -h github.com -s project
fi

# ---- Step 1: Create Project ----
header "Creating GitHub Project"

PROJECT_JSON=$(gh api graphql -f query='
mutation {
  createProjectV2(input: {
    ownerId: "'"$(gh api graphql -f query='query { user(login: "'"$OWNER"'") { id } }' --jq '.data.user.id')"'"
    title: "'"$PROJECT_NAME"'"
  }) { projectV2 { id number } }
}' --jq '.data.createProjectV2.projectV2' 2>/dev/null) || {
    err "Failed to create project. It may already exist."
    echo ""
    info "To use an existing project, set CC_GITHUB_OWNER, CC_GITHUB_REPO and CC_PROJECT_NUMBER, then run:"
    echo "  ./setup.sh --sync"
    exit 1
}
PROJECT_ID=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$PROJECT_JSON")
PROJECT_NUMBER=$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["number"])' "$PROJECT_JSON")

info "Project created: ${PROJECT_ID} (number ${PROJECT_NUMBER})"

# ---- Step 2: Get Status Field ID ----
header "Configuring Status field"

STATUS_FIELD_ID=$(gh api graphql -f query='
query {
  node(id: "'"$PROJECT_ID"'") {
    ... on ProjectV2 {
      field(name: "Status") {
        ... on ProjectV2SingleSelectField { id }
      }
    }
  }
}' --jq '.data.node.field.id')

info "Status field: ${STATUS_FIELD_ID}"

# Configure status columns
STATUS_RESULT=$(gh api graphql -f query='
mutation {
  updateProjectV2Field(input: {
    fieldId: "'"$STATUS_FIELD_ID"'"
    singleSelectOptions: [
      { name: "Roadmap", color: PINK, description: "Feature ideas and future enhancements" }
      { name: "Backlog", color: GRAY, description: "Accepted work, no sprint assigned" }
      { name: "Todo", color: BLUE, description: "Committed to sprint, not started" }
      { name: "In Progress", color: YELLOW, description: "Actively being developed" }
      { name: "To Be Tested", color: ORANGE, description: "Code complete, needs verification" }
      { name: "Done", color: GREEN, description: "Verified and closed" }
      { name: "Canceled", color: RED, description: "Abandoned or deferred" }
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        options { id name }
      }
    }
  }
}' --jq '.data.updateProjectV2Field.projectV2Field.options')

info "Status columns configured"
echo "$STATUS_RESULT" | python3 -c "
import json, sys
for opt in json.load(sys.stdin):
    print(f\"  {opt['name']:20s} -> {opt['id']}\")
" 2>/dev/null || echo "$STATUS_RESULT"

# ---- Step 3: Create Area Field ----
header "Creating Area field"

AREA_RESULT=$(gh api graphql -f query='
mutation {
  createProjectV2Field(input: {
    projectId: "'"$PROJECT_ID"'"
    dataType: SINGLE_SELECT
    name: "Area"
    singleSelectOptions: [
      { name: "CI/CD", color: BLUE, description: "Build pipeline and deployment" }
      { name: "Monitoring", color: PURPLE, description: "Metrics, alerting, dashboards" }
      { name: "Testing", color: YELLOW, description: "Test framework and coverage" }
      { name: "Security", color: RED, description: "Access control and scanning" }
      { name: "Infrastructure", color: ORANGE, description: "Servers, backup, networking" }
    ]
  }) {
    projectV2Field {
      ... on ProjectV2SingleSelectField {
        id
        options { id name }
      }
    }
  }
}')

AREA_FIELD_ID=$(echo "$AREA_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['createProjectV2Field']['projectV2Field']['id'])" 2>/dev/null)
info "Area field: ${AREA_FIELD_ID}"

# ---- Step 4: Create Sprint Field ----
header "Creating Sprint field"

TODAY=$(date +%Y-%m-%d)
SPRINT_RESULT=$(gh api graphql -f query='
mutation {
  createProjectV2Field(input: {
    projectId: "'"$PROJECT_ID"'"
    dataType: ITERATION
    name: "Sprint"
    iterationConfiguration: {
      startDate: "'"$TODAY"'"
      duration: 14
      iterations: [
        { title: "Sprint 1", startDate: "'"$TODAY"'", duration: 14 }
      ]
    }
  }) {
    projectV2Field {
      ... on ProjectV2IterationField {
        id
        configuration {
          iterations { id title startDate duration }
        }
      }
    }
  }
}')

SPRINT_FIELD_ID=$(echo "$SPRINT_RESULT" | python3 -c "import json,sys; print(json.load(sys.stdin)['data']['createProjectV2Field']['projectV2Field']['id'])" 2>/dev/null)
info "Sprint field: ${SPRINT_FIELD_ID}"

# ---- Step 5: Create Labels ----
header "Creating labels on ${OWNER}/${REPO}"

while IFS='|' read -r label color desc; do
    if gh label create "$label" --repo "${OWNER}/${REPO}" --color "$color" --description "$desc" 2>/dev/null; then
        info "Created: ${label}"
    else
        warn "Exists: ${label}"
    fi
done < <(labels)

# ---- Step 6: Set Project README ----
header "Setting project README"

gh api graphql -f query='
mutation {
  updateProjectV2(input: {
    projectId: "'"$PROJECT_ID"'"
    shortDescription: "Sprint board, issue tracking, and release management"
    readme: "# '"$PROJECT_NAME"' Board\n\n## Board Structure\n\n### Status (Columns)\n| Column | Meaning |\n|--------|---------|\n| **Roadmap** | Feature ideas, not committed |\n| **Backlog** | Accepted work, no sprint |\n| **Todo** | Committed to sprint |\n| **In Progress** | Actively developed |\n| **To Be Tested** | Code complete, verify |\n| **Done** | Verified and closed |\n| **Canceled** | Abandoned or deferred |\n\n### Area (Group By)\nCI/CD, Monitoring, Testing, Security, Infrastructure\n\n### Sprint\n14-day iterations. Filter by Sprint to focus."
  }) { projectV2 { title } }
}' >/dev/null

info "README set"

# ---- Output Configuration ----
header "Configuration Output"

echo ""
echo "Add these to your cognitive-core.conf, then run ./setup.sh --sync to record the status option IDs:"
echo ""
echo "CC_PROJECT_BOARD_PROVIDER=\"github\""
echo "CC_GITHUB_OWNER=\"${OWNER}\""
echo "CC_GITHUB_REPO=\"${OWNER}/${REPO}\""
echo "CC_PROJECT_NUMBER=\"${PROJECT_NUMBER}\""
echo "CC_AREA_FIELD_ID=\"${AREA_FIELD_ID}\""
echo "CC_SPRINT_FIELD_ID=\"${SPRINT_FIELD_ID}\""
echo ""

header "Setup Complete"
info "Next: Add issues with /project-board create or drag existing issues onto the board"
