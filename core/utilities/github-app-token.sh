#!/usr/bin/env bash
# github-app-token.sh — Generate GitHub App installation token
#
# Usage:
#   github-app-token.sh [--installation-id ID] [--config PATH] [--pem PATH]
#
# Generates a short-lived (1h) installation access token for a GitHub App.
# Used by the code-standards-reviewer agent to post PR reviews as a
# separate identity, satisfying branch protection review requirements.
#
# Default config: ~/.config/github/reviewer-app.json
# Default PEM:    ~/.config/github/reviewer-app.pem
#
# Override via:
#   CC_REVIEWER_APP_CONFIG (env or cognitive-core.conf)
#   CC_REVIEWER_APP_PEM    (env or cognitive-core.conf)
#
# Config JSON format:
#   {
#     "app_id": "123456",
#     "default_installation_id": "789012",
#     "installations": { "org-name": "789012" }
#   }
#
# See docs/GITHUB_APP_REVIEWER.md for setup instructions.

set -euo pipefail

# Defaults (overridable via env, cognitive-core.conf, or CLI flags)
CONFIG_FILE="${CC_REVIEWER_APP_CONFIG:-${HOME}/.config/github/reviewer-app.json}"
PEM_FILE="${CC_REVIEWER_APP_PEM:-${HOME}/.config/github/reviewer-app.pem}"

# Parse args
INSTALLATION_ID=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --installation-id) INSTALLATION_ID="$2"; shift 2 ;;
        --config) CONFIG_FILE="$2"; shift 2 ;;
        --pem) PEM_FILE="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: github-app-token.sh [--installation-id ID] [--config PATH] [--pem PATH]"
            echo ""
            echo "Generates a short-lived GitHub App installation access token."
            echo "See docs/GITHUB_APP_REVIEWER.md for setup instructions."
            exit 0
            ;;
        *) echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

# Load config
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Config not found: $CONFIG_FILE" >&2
    echo "Create it from cicd/templates/reviewer-app.json.example" >&2
    exit 1
fi

APP_ID=$(jq -r '.app_id' "$CONFIG_FILE")
DEFAULT_INSTALLATION_ID=$(jq -r '.default_installation_id' "$CONFIG_FILE")
INSTALLATION_ID="${INSTALLATION_ID:-$DEFAULT_INSTALLATION_ID}"

if [[ ! -f "$PEM_FILE" ]]; then
    echo "PEM file not found: $PEM_FILE" >&2
    echo "Download from GitHub App settings → Private keys" >&2
    exit 1
fi

# Generate JWT (valid for 10 minutes)
NOW=$(date +%s)
IAT=$((NOW - 60))
EXP=$((NOW + 600))

HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$IAT" "$EXP" "$APP_ID" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
SIGNATURE=$(printf '%s.%s' "$HEADER" "$PAYLOAD" | openssl dgst -sha256 -sign "$PEM_FILE" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
JWT="${HEADER}.${PAYLOAD}.${SIGNATURE}"

# Exchange JWT for installation access token
RESPONSE=$(curl -s -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer ${JWT}" \
    "https://api.github.com/app/installations/${INSTALLATION_ID}/access_tokens")

TOKEN=$(echo "$RESPONSE" | jq -r '.token // empty')

if [[ -z "$TOKEN" ]]; then
    echo "Failed to get token: $(echo "$RESPONSE" | jq -r '.message // "unknown error"')" >&2
    exit 1
fi

echo "$TOKEN"
