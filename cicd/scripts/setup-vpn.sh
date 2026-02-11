#!/usr/bin/env bash
# =============================================================================
# WireGuard VPN Setup — cognitive-core framework
# =============================================================================
# Installs and configures WireGuard for secure runner-to-monitoring tunnels.
# Supports --server and --client modes for easy multi-node deployment.
#
# Features:
#   - Automatic key generation
#   - Server mode: creates wg0.conf with peer stubs
#   - Client mode: creates wg0.conf from server-provided parameters
#   - systemd service management
#   - Uses CC_* config vars from cognitive-core.conf
#
# Usage:
#   # Server mode (on monitoring/VPN host):
#   bash setup-vpn.sh --server --endpoint vpn.example.com --peers 3
#
#   # Client mode (on runner nodes):
#   bash setup-vpn.sh --client \
#     --endpoint vpn.example.com \
#     --server-pubkey <SERVER_PUBLIC_KEY> \
#     --client-ip 10.13.13.2/32
#
#   # With cognitive-core.conf:
#   bash setup-vpn.sh --server --config /path/to/cognitive-core.conf
#
# Environment variables (alternative to flags):
#   CC_PROJECT_NAME, CC_ORG
#   WG_ENDPOINT, WG_PORT, WG_SUBNET, WG_PEERS
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration defaults
# ---------------------------------------------------------------------------
MODE=""
CONFIG_FILE=""
WG_INTERFACE="wg0"
WG_PORT="${WG_PORT:-51820}"
WG_SUBNET="${WG_SUBNET:-10.13.13.0/24}"
WG_SUBNET_BASE="${WG_SUBNET_BASE:-10.13.13}"
WG_ENDPOINT="${WG_ENDPOINT:-}"
WG_PEERS="${WG_PEERS:-1}"
WG_DNS="${WG_DNS:-1.1.1.1}"
WG_CONFIG_DIR="/etc/wireguard"
WG_KEEPALIVE="${WG_KEEPALIVE:-25}"
ENABLE_SERVICE=true

# Client-specific
SERVER_PUBKEY=""
CLIENT_IP=""

# Project identity (from cognitive-core.conf if sourced)
CC_PROJECT_NAME="${CC_PROJECT_NAME:-}"
CC_ORG="${CC_ORG:-}"

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --server)         MODE="server"; shift ;;
        --client)         MODE="client"; shift ;;
        --config)         CONFIG_FILE="$2"; shift 2 ;;
        --endpoint)       WG_ENDPOINT="$2"; shift 2 ;;
        --port)           WG_PORT="$2"; shift 2 ;;
        --subnet)         WG_SUBNET="$2"; shift 2 ;;
        --peers)          WG_PEERS="$2"; shift 2 ;;
        --dns)            WG_DNS="$2"; shift 2 ;;
        --interface)      WG_INTERFACE="$2"; shift 2 ;;
        --server-pubkey)  SERVER_PUBKEY="$2"; shift 2 ;;
        --client-ip)      CLIENT_IP="$2"; shift 2 ;;
        --keepalive)      WG_KEEPALIVE="$2"; shift 2 ;;
        --no-service)     ENABLE_SERVICE=false; shift ;;
        --help|-h)
            cat <<'HELP'
Usage: setup-vpn.sh --server|--client [options]

Modes:
  --server               Configure as WireGuard server
  --client               Configure as WireGuard client

Common options:
  --config FILE          Source cognitive-core.conf for CC_* variables
  --endpoint HOST        Server public hostname/IP (required)
  --port PORT            WireGuard listen port (default: 51820)
  --interface IFACE      WireGuard interface name (default: wg0)
  --dns DNS              DNS server for clients (default: 1.1.1.1)
  --keepalive SECS       Persistent keepalive interval (default: 25)
  --no-service           Do not enable systemd service

Server options:
  --subnet CIDR          VPN subnet (default: 10.13.13.0/24)
  --peers N              Number of peer configs to generate (default: 1)

Client options:
  --server-pubkey KEY    Server's public key (required)
  --client-ip CIDR       This client's VPN IP (e.g., 10.13.13.2/32)

Examples:
  setup-vpn.sh --server --endpoint vpn.example.com --peers 3
  setup-vpn.sh --client --endpoint vpn.example.com --server-pubkey ABC= --client-ip 10.13.13.2/32
HELP
            exit 0 ;;
        *)
            echo "Unknown option: $1"
            exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Source config file if provided
# ---------------------------------------------------------------------------
if [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    echo "Sourcing configuration from ${CONFIG_FILE}..."
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

# ---------------------------------------------------------------------------
# Validate mode
# ---------------------------------------------------------------------------
if [ -z "$MODE" ]; then
    echo "Error: --server or --client mode is required"
    echo "Run with --help for usage information"
    exit 1
fi

if [ -z "$WG_ENDPOINT" ]; then
    echo "Error: --endpoint is required"
    exit 1
fi

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*" >&2
}

log_error() {
    echo "[ERROR] $*" >&2
}

generate_keypair() {
    local private_key public_key
    private_key=$(wg genkey)
    public_key=$(echo "$private_key" | wg pubkey)
    echo "${private_key} ${public_key}"
}

# ---------------------------------------------------------------------------
# Install WireGuard
# ---------------------------------------------------------------------------
install_wireguard() {
    log_info "Checking WireGuard installation..."

    if command -v wg &>/dev/null; then
        log_info "WireGuard already installed: $(wg --version 2>&1 || echo 'version unknown')"
        return 0
    fi

    log_info "Installing WireGuard..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update
        sudo apt-get install -y wireguard wireguard-tools
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y wireguard-tools
    elif command -v yum &>/dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y wireguard-tools
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm wireguard-tools
    else
        log_error "Unsupported package manager. Install WireGuard manually."
        exit 1
    fi

    log_info "WireGuard installed successfully"
}

# ---------------------------------------------------------------------------
# Server setup
# ---------------------------------------------------------------------------
setup_server() {
    log_info "Configuring WireGuard server..."

    # Generate server keys
    local keypair server_private server_public
    keypair=$(generate_keypair)
    server_private=$(echo "$keypair" | awk '{print $1}')
    server_public=$(echo "$keypair" | awk '{print $2}')

    log_info "Server public key: ${server_public}"

    # Create config directory
    sudo mkdir -p "$WG_CONFIG_DIR"
    sudo chmod 700 "$WG_CONFIG_DIR"

    # Build server config
    local server_config="${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"
    local server_ip="${WG_SUBNET_BASE}.1/24"

    log_info "Creating server config: ${server_config}"

    sudo tee "$server_config" > /dev/null <<EOF
# =============================================================================
# WireGuard Server Configuration — cognitive-core framework
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Project: ${CC_PROJECT_NAME:-cognitive-core}
# =============================================================================

[Interface]
Address = ${server_ip}
ListenPort = ${WG_PORT}
PrivateKey = ${server_private}

# Enable IP forwarding (uncomment if not set system-wide)
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
EOF

    # Generate peer configs
    local peer_dir="${WG_CONFIG_DIR}/peers"
    sudo mkdir -p "$peer_dir"

    local i
    for i in $(seq 1 "$WG_PEERS"); do
        local peer_keypair peer_private peer_public peer_ip
        peer_keypair=$(generate_keypair)
        peer_private=$(echo "$peer_keypair" | awk '{print $1}')
        peer_public=$(echo "$peer_keypair" | awk '{print $2}')
        peer_ip="${WG_SUBNET_BASE}.$((i + 1))/32"

        # Append peer to server config
        sudo tee -a "$server_config" > /dev/null <<EOF

# Peer ${i}: runner-${i}
[Peer]
PublicKey = ${peer_public}
AllowedIPs = ${peer_ip}
EOF

        # Create client config for this peer
        local peer_config="${peer_dir}/peer-${i}.conf"
        sudo tee "$peer_config" > /dev/null <<EOF
# =============================================================================
# WireGuard Client Configuration — Peer ${i}
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Project: ${CC_PROJECT_NAME:-cognitive-core}
# =============================================================================

[Interface]
Address = ${WG_SUBNET_BASE}.$((i + 1))/32
PrivateKey = ${peer_private}
DNS = ${WG_DNS}

[Peer]
PublicKey = ${server_public}
Endpoint = ${WG_ENDPOINT}:${WG_PORT}
AllowedIPs = ${WG_SUBNET}
PersistentKeepalive = ${WG_KEEPALIVE}
EOF

        sudo chmod 600 "$peer_config"
        log_info "Generated peer config: ${peer_config}"
    done

    # Secure the server config
    sudo chmod 600 "$server_config"

    log_info "Server config written to: ${server_config}"
    log_info "Peer configs written to: ${peer_dir}/"
    echo ""
    echo "========================================="
    echo "  Server Public Key (share with peers):"
    echo "  ${server_public}"
    echo "========================================="
}

# ---------------------------------------------------------------------------
# Client setup
# ---------------------------------------------------------------------------
setup_client() {
    log_info "Configuring WireGuard client..."

    if [ -z "$SERVER_PUBKEY" ]; then
        log_error "--server-pubkey is required in client mode"
        exit 1
    fi

    if [ -z "$CLIENT_IP" ]; then
        log_error "--client-ip is required in client mode"
        exit 1
    fi

    # Generate client keys
    local keypair client_private client_public
    keypair=$(generate_keypair)
    client_private=$(echo "$keypair" | awk '{print $1}')
    client_public=$(echo "$keypair" | awk '{print $2}')

    log_info "Client public key: ${client_public}"

    # Create config directory
    sudo mkdir -p "$WG_CONFIG_DIR"
    sudo chmod 700 "$WG_CONFIG_DIR"

    # Build client config
    local client_config="${WG_CONFIG_DIR}/${WG_INTERFACE}.conf"

    log_info "Creating client config: ${client_config}"

    sudo tee "$client_config" > /dev/null <<EOF
# =============================================================================
# WireGuard Client Configuration — cognitive-core framework
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Project: ${CC_PROJECT_NAME:-cognitive-core}
# =============================================================================

[Interface]
Address = ${CLIENT_IP}
PrivateKey = ${client_private}
DNS = ${WG_DNS}

[Peer]
PublicKey = ${SERVER_PUBKEY}
Endpoint = ${WG_ENDPOINT}:${WG_PORT}
AllowedIPs = ${WG_SUBNET}
PersistentKeepalive = ${WG_KEEPALIVE}
EOF

    sudo chmod 600 "$client_config"

    log_info "Client config written to: ${client_config}"
    echo ""
    echo "========================================="
    echo "  Client Public Key (add to server):"
    echo "  ${client_public}"
    echo ""
    echo "  Add this to your server's wg0.conf:"
    echo "  [Peer]"
    echo "  PublicKey = ${client_public}"
    echo "  AllowedIPs = ${CLIENT_IP}"
    echo "========================================="
}

# ---------------------------------------------------------------------------
# Enable systemd service
# ---------------------------------------------------------------------------
enable_service() {
    if [ "$ENABLE_SERVICE" != "true" ]; then
        log_info "Skipping systemd service (--no-service)"
        return 0
    fi

    if ! command -v systemctl &>/dev/null; then
        log_warn "systemctl not found — skipping service setup"
        log_info "Start manually with: sudo wg-quick up ${WG_INTERFACE}"
        return 0
    fi

    log_info "Enabling WireGuard systemd service..."

    sudo systemctl enable "wg-quick@${WG_INTERFACE}"
    sudo systemctl start "wg-quick@${WG_INTERFACE}"

    log_info "Service wg-quick@${WG_INTERFACE} is active"
    echo ""
    echo "Service commands:"
    echo "  sudo systemctl status wg-quick@${WG_INTERFACE}"
    echo "  sudo systemctl restart wg-quick@${WG_INTERFACE}"
    echo "  sudo wg show ${WG_INTERFACE}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "========================================="
echo "  WireGuard VPN Setup"
echo "========================================="
echo "  Mode:      ${MODE}"
echo "  Endpoint:  ${WG_ENDPOINT}"
echo "  Port:      ${WG_PORT}"
echo "  Interface: ${WG_INTERFACE}"
if [ -n "$CC_PROJECT_NAME" ]; then
    echo "  Project:   ${CC_PROJECT_NAME}"
fi
echo "========================================="
echo ""

install_wireguard

case "$MODE" in
    server) setup_server ;;
    client) setup_client ;;
    *)      log_error "Invalid mode: ${MODE}"; exit 1 ;;
esac

enable_service

echo ""
echo "========================================="
echo "  WireGuard ${MODE} setup complete"
echo "========================================="
