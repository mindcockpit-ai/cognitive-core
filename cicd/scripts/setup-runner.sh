#!/usr/bin/env bash
# =============================================================================
# GitHub Actions Self-Hosted Runner Setup — cognitive-core framework
# =============================================================================
# Installs and configures a self-hosted GitHub Actions runner.
# Fully parameterized — no hardcoded org/repo values.
#
# Features:
#   - Multi-node support with --node-id
#   - Docker prerequisite check
#   - systemd service installation (optional)
#   - Parameterized ORG/REPO via arguments or environment
#
# Usage:
#   bash setup-runner.sh --org myorg --repo myrepo --token AXXXX
#   bash setup-runner.sh --org myorg --repo myrepo --token AXXXX --node-id 2
#   bash setup-runner.sh --org myorg --repo myrepo --token AXXXX --service
#
# Environment variables (alternative to flags):
#   GITHUB_ORG, GITHUB_REPO, RUNNER_TOKEN, RUNNER_NODE_ID
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
RUNNER_VERSION="${RUNNER_VERSION:-2.321.0}"
RUNNER_ARCH="${RUNNER_ARCH:-linux-x64}"
RUNNER_DIR_BASE="${RUNNER_DIR:-/opt/actions-runner}"
ORG="${GITHUB_ORG:-}"
REPO="${GITHUB_REPO:-}"
TOKEN="${RUNNER_TOKEN:-}"
NODE_ID="${RUNNER_NODE_ID:-1}"
INSTALL_SERVICE=false
LABELS="${RUNNER_LABELS:-self-hosted,linux,x64}"
RUNNER_GROUP="${RUNNER_GROUP:-default}"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --org)       ORG="$2"; shift 2 ;;
        --repo)      REPO="$2"; shift 2 ;;
        --token)     TOKEN="$2"; shift 2 ;;
        --node-id)   NODE_ID="$2"; shift 2 ;;
        --labels)    LABELS="$2"; shift 2 ;;
        --group)     RUNNER_GROUP="$2"; shift 2 ;;
        --dir)       RUNNER_DIR_BASE="$2"; shift 2 ;;
        --version)   RUNNER_VERSION="$2"; shift 2 ;;
        --service)   INSTALL_SERVICE=true; shift ;;
        --help|-h)
            echo "Usage: setup-runner.sh --org ORG --repo REPO --token TOKEN [options]"
            echo ""
            echo "Options:"
            echo "  --org ORG        GitHub organization (required)"
            echo "  --repo REPO      GitHub repository (required)"
            echo "  --token TOKEN    Runner registration token (required)"
            echo "  --node-id N      Node identifier for multi-node setup (default: 1)"
            echo "  --labels LABELS  Comma-separated labels (default: self-hosted,linux,x64)"
            echo "  --group GROUP    Runner group (default: default)"
            echo "  --dir DIR        Base install directory (default: /opt/actions-runner)"
            echo "  --version VER    Runner version (default: ${RUNNER_VERSION})"
            echo "  --service        Install as systemd service"
            exit 0 ;;
        *)
            echo "Unknown option: $1"
            exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Validate required parameters
# ---------------------------------------------------------------------------
if [ -z "$ORG" ]; then
    echo "Error: --org is required (or set GITHUB_ORG env var)"
    exit 1
fi
if [ -z "$REPO" ]; then
    echo "Error: --repo is required (or set GITHUB_REPO env var)"
    exit 1
fi
if [ -z "$TOKEN" ]; then
    echo "Error: --token is required (or set RUNNER_TOKEN env var)"
    exit 1
fi

# Node-specific runner directory
RUNNER_DIR="${RUNNER_DIR_BASE}-${NODE_ID}"
RUNNER_NAME="runner-${NODE_ID}"

echo "========================================="
echo "  GitHub Actions Runner Setup"
echo "========================================="
echo "  Organization: ${ORG}"
echo "  Repository:   ${REPO}"
echo "  Node ID:      ${NODE_ID}"
echo "  Runner name:  ${RUNNER_NAME}"
echo "  Install dir:  ${RUNNER_DIR}"
echo "  Version:      ${RUNNER_VERSION}"
echo "  Labels:       ${LABELS}"
echo "========================================="
echo ""

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
echo "Checking prerequisites..."

# Check running as non-root (runner should not run as root)
if [ "$(id -u)" -eq 0 ]; then
    echo "Warning: Running as root is not recommended for the runner."
    echo "Consider creating a dedicated 'runner' user."
fi

# Check Docker
if command -v docker &>/dev/null; then
    echo "  [OK] Docker: $(docker --version)"
    # Check Docker socket access
    if docker info &>/dev/null 2>&1; then
        echo "  [OK] Docker socket: accessible"
    else
        echo "  [WARN] Docker socket: not accessible (add user to docker group)"
        echo "         Run: sudo usermod -aG docker \$(whoami)"
    fi
else
    echo "  [WARN] Docker: NOT installed"
    echo "         Docker is recommended for container-based workflow steps."
    echo "         Install: https://docs.docker.com/engine/install/"
fi

# Check curl
if ! command -v curl &>/dev/null; then
    echo "  [FAIL] curl is required but not installed"
    exit 1
fi
echo "  [OK] curl: available"

# Check tar
if ! command -v tar &>/dev/null; then
    echo "  [FAIL] tar is required but not installed"
    exit 1
fi
echo "  [OK] tar: available"

# Check disk space (need at least 2GB)
AVAILABLE_KB=$(df -k "${RUNNER_DIR_BASE%/*}" 2>/dev/null | tail -1 | awk '{print $4}')
if [ -n "$AVAILABLE_KB" ] && [ "$AVAILABLE_KB" -lt 2097152 ]; then
    echo "  [WARN] Less than 2GB disk space available"
fi

echo ""

# ---------------------------------------------------------------------------
# Download and extract runner
# ---------------------------------------------------------------------------
echo "Installing runner to ${RUNNER_DIR}..."

sudo mkdir -p "$RUNNER_DIR"
sudo chown "$(id -u):$(id -g)" "$RUNNER_DIR"
cd "$RUNNER_DIR"

# Download runner package
RUNNER_TAR="actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz"
RUNNER_URL="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${RUNNER_TAR}"

if [ ! -f "$RUNNER_TAR" ]; then
    echo "Downloading runner v${RUNNER_VERSION}..."
    curl -sL -o "$RUNNER_TAR" "$RUNNER_URL"
else
    echo "Runner archive already downloaded."
fi

# Verify download
if [ ! -s "$RUNNER_TAR" ]; then
    echo "Error: Download failed or file is empty"
    exit 1
fi

# Extract
echo "Extracting..."
tar xzf "$RUNNER_TAR"

# ---------------------------------------------------------------------------
# Configure runner
# ---------------------------------------------------------------------------
echo "Configuring runner..."

./config.sh \
    --url "https://github.com/${ORG}/${REPO}" \
    --token "$TOKEN" \
    --name "$RUNNER_NAME" \
    --labels "$LABELS" \
    --runnergroup "$RUNNER_GROUP" \
    --work "_work" \
    --unattended \
    --replace

echo ""
echo "Runner configured successfully."

# ---------------------------------------------------------------------------
# Install systemd service (optional)
# ---------------------------------------------------------------------------
if [ "$INSTALL_SERVICE" = "true" ]; then
    echo ""
    echo "Installing systemd service..."

    SERVICE_NAME="actions.runner.${ORG}-${REPO}.${RUNNER_NAME}"

    # Use the built-in service installer
    if [ -f "./svc.sh" ]; then
        sudo ./svc.sh install
        sudo ./svc.sh start
        echo ""
        echo "Service installed and started: ${SERVICE_NAME}"
        echo "Commands:"
        echo "  sudo ./svc.sh status    # Check status"
        echo "  sudo ./svc.sh stop      # Stop runner"
        echo "  sudo ./svc.sh start     # Start runner"
        echo "  sudo ./svc.sh uninstall # Remove service"
    else
        echo "Warning: svc.sh not found — creating manual service file"

        cat <<UNIT | sudo tee "/etc/systemd/system/${SERVICE_NAME}.service" > /dev/null
[Unit]
Description=GitHub Actions Runner (${RUNNER_NAME})
After=network.target

[Service]
ExecStart=${RUNNER_DIR}/run.sh
User=$(whoami)
WorkingDirectory=${RUNNER_DIR}
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=5min
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT

        sudo systemctl daemon-reload
        sudo systemctl enable "$SERVICE_NAME"
        sudo systemctl start "$SERVICE_NAME"
        echo "Service installed: ${SERVICE_NAME}"
    fi
else
    echo ""
    echo "To run interactively:"
    echo "  cd ${RUNNER_DIR} && ./run.sh"
    echo ""
    echo "To install as service:"
    echo "  bash setup-runner.sh --org ${ORG} --repo ${REPO} --token TOKEN --node-id ${NODE_ID} --service"
fi

echo ""
echo "========================================="
echo "  Runner setup complete"
echo "========================================="
echo "  Name:   ${RUNNER_NAME}"
echo "  Dir:    ${RUNNER_DIR}"
echo "  Labels: ${LABELS}"
echo "========================================="
