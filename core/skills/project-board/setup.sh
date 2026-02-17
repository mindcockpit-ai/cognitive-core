#!/bin/bash
# =============================================================================
# project-board setup — Creates GitHub Project with standard board structure
#
# Configures: Status columns, Area grouping, Sprint iterations, Labels
# Requires: gh CLI with project scope authenticated
#
# Usage:
#   ./setup.sh <owner> <repo> [project-name]
#   ./setup.sh wolaschka TIMS "IPMS Development"
# =============================================================================
set -euo pipefail

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

# ---- Parse arguments ----
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

PROJECT_ID=$(gh api graphql -f query='
mutation {
  createProjectV2(input: {
    ownerId: "'"$(gh api graphql -f query='query { user(login: "'"$OWNER"'") { id } }' --jq '.data.user.id')"'"
    title: "'"$PROJECT_NAME"'"
  }) { projectV2 { id number } }
}' --jq '.data.createProjectV2.projectV2.id' 2>/dev/null) || {
    err "Failed to create project. It may already exist."
    echo ""
    info "To use an existing project, find its ID with:"
    echo "  gh project list --owner $OWNER"
    exit 1
}

PROJECT_NUMBER=$(gh api graphql -f query='
query {
  user(login: "'"$OWNER"'") {
    projectV2(number: 100) { number }
  }
}' --jq '.data.user.projectV2.number' 2>/dev/null || echo "unknown")

info "Project created: ${PROJECT_ID}"

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
    print(f\"  {opt['name']:20s} → {opt['id']}\")
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

echo "$AREA_RESULT" | python3 -c "
import json, sys
for opt in json.load(sys.stdin)['data']['createProjectV2Field']['projectV2Field']['options']:
    print(f\"  {opt['name']:20s} → {opt['id']}\")
" 2>/dev/null || true

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

declare -A LABELS=(
    ["priority:p0-critical"]="B60205:Critical priority"
    ["priority:p1-high"]="D93F0B:High priority"
    ["priority:p2-medium"]="FBCA04:Medium priority"
    ["priority:p3-low"]="0E8A16:Low priority"
    ["area:cicd"]="1D76DB:CI/CD pipeline"
    ["area:monitoring"]="7057FF:Monitoring and alerting"
    ["area:testing"]="FFDD57:Testing framework"
    ["area:security"]="E11D48:Security"
    ["area:infrastructure"]="F9A825:Infrastructure"
)

for label in "${!LABELS[@]}"; do
    IFS=: read -r color desc <<< "${LABELS[$label]}"
    gh label create "$label" --repo "${OWNER}/${REPO}" --color "$color" --description "$desc" 2>/dev/null && \
        info "Created: ${label}" || warn "Exists: ${label}"
done

# ---- Step 6: Set Project README ----
header "Setting project README"

gh api graphql -f query='
mutation {
  updateProjectV2(input: {
    projectId: "'"$PROJECT_ID"'"
    shortDescription: "Sprint board, issue tracking, and release management"
    readme: "# '"$PROJECT_NAME"' Board\n\n## Board Structure\n\n### Status (Columns)\n| Column | Meaning |\n|--------|---------|\n| **Roadmap** | Feature ideas, not committed |\n| **Backlog** | Accepted work, no sprint |\n| **Todo** | Committed to sprint |\n| **In Progress** | Actively developed |\n| **To Be Tested** | Code complete, verify |\n| **Done** | Verified and closed |\n\n### Area (Group By)\nCI/CD, Monitoring, Testing, Security, Infrastructure\n\n### Sprint\n14-day iterations. Filter by Sprint to focus."
  }) { projectV2 { title } }
}' >/dev/null

info "README set"

# ---- Output Configuration ----
header "Configuration Output"

echo ""
echo "Add these to your cognitive-core.conf or skill configuration:"
echo ""
echo "CC_GITHUB_REPO=\"${OWNER}/${REPO}\""
echo "CC_PROJECT_NUMBER=${PROJECT_NUMBER}"
echo "CC_PROJECT_ID=\"${PROJECT_ID}\""
echo "CC_STATUS_FIELD_ID=\"${STATUS_FIELD_ID}\""
echo "CC_AREA_FIELD_ID=\"${AREA_FIELD_ID}\""
echo "CC_SPRINT_FIELD_ID=\"${SPRINT_FIELD_ID}\""
echo ""

# Save to .project-board.env for skill reference
ENV_FILE="${SCRIPT_DIR:-.}/.project-board.env"
cat > "$ENV_FILE" << ENVEOF
# Generated by project-board setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
CC_GITHUB_REPO="${OWNER}/${REPO}"
CC_PROJECT_NUMBER=${PROJECT_NUMBER}
CC_PROJECT_ID="${PROJECT_ID}"
CC_STATUS_FIELD_ID="${STATUS_FIELD_ID}"
CC_AREA_FIELD_ID="${AREA_FIELD_ID}"
CC_SPRINT_FIELD_ID="${SPRINT_FIELD_ID}"
ENVEOF
info "Saved to: ${ENV_FILE}"

header "Setup Complete"
info "Board URL: https://github.com/users/${OWNER}/projects/${PROJECT_NUMBER}"
info "Next: Add issues with /project-board create or drag existing issues onto the board"
