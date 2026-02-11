#!/usr/bin/env bash
# =============================================================================
# Firewall Setup — cognitive-core framework
# =============================================================================
# Configures UFW or iptables firewall rules for the CI/CD infrastructure.
# Allows only required ports and restricts internal services to localhost.
#
# Features:
#   - Automatic UFW/iptables detection
#   - --dry-run mode to preview rules without applying
#   - Configurable ports via arguments or CC_* env vars
#   - Pushgateway (9091) restricted to localhost only
#   - Safe defaults: deny all incoming, allow all outgoing
#
# Allowed ports:
#   22/tcp      SSH
#   80/tcp      HTTP
#   443/tcp     HTTPS
#   51820/udp   WireGuard VPN
#   9090/tcp    Prometheus
#   3000/tcp    Grafana
#   9091/tcp    Pushgateway (localhost only)
#
# Usage:
#   bash setup-firewall.sh                      # Apply with UFW or iptables
#   bash setup-firewall.sh --dry-run            # Preview rules only
#   bash setup-firewall.sh --backend iptables   # Force iptables backend
#   bash setup-firewall.sh --config /path/to/cognitive-core.conf
#
# Environment variables:
#   CC_PROJECT_NAME   Project identifier (for logging)
#   FW_EXTRA_PORTS    Additional ports to allow (space-separated, e.g., "8080/tcp 5432/tcp")
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
DRY_RUN=false
BACKEND=""
CONFIG_FILE=""
CC_PROJECT_NAME="${CC_PROJECT_NAME:-}"
FW_EXTRA_PORTS="${FW_EXTRA_PORTS:-}"

# Standard ports to allow (incoming)
declare -a ALLOW_PORTS=(
    "22/tcp"       # SSH
    "80/tcp"       # HTTP
    "443/tcp"      # HTTPS
    "51820/udp"    # WireGuard
    "9090/tcp"     # Prometheus
    "3000/tcp"     # Grafana
)

# Ports restricted to localhost only
declare -a LOCALHOST_PORTS=(
    "9091/tcp"     # Pushgateway
)

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)    DRY_RUN=true; shift ;;
        --backend)    BACKEND="$2"; shift 2 ;;
        --config)     CONFIG_FILE="$2"; shift 2 ;;
        --extra-port) FW_EXTRA_PORTS="${FW_EXTRA_PORTS} $2"; shift 2 ;;
        --help|-h)
            cat <<'HELP'
Usage: setup-firewall.sh [options]

Options:
  --dry-run              Preview rules without applying them
  --backend ufw|iptables Force a specific firewall backend
  --config FILE          Source cognitive-core.conf for CC_* variables
  --extra-port PORT/PROTO Additional port to allow (repeatable)
  --help, -h             Show this help message

Allowed ports:
  22/tcp       SSH
  80/tcp       HTTP
  443/tcp      HTTPS
  51820/udp    WireGuard VPN
  9090/tcp     Prometheus
  3000/tcp     Grafana
  9091/tcp     Pushgateway (localhost only)

Examples:
  setup-firewall.sh --dry-run
  setup-firewall.sh --backend ufw
  setup-firewall.sh --extra-port 8080/tcp --extra-port 5432/tcp
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

# Add extra ports from environment
if [ -n "$FW_EXTRA_PORTS" ]; then
    for port in $FW_EXTRA_PORTS; do
        ALLOW_PORTS+=("$port")
    done
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

log_rule() {
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY-RUN] $*"
    else
        echo "[APPLY]   $*"
    fi
}

run_cmd() {
    if [ "$DRY_RUN" = "true" ]; then
        echo "  -> $*"
    else
        eval "$@"
    fi
}

# ---------------------------------------------------------------------------
# Detect firewall backend
# ---------------------------------------------------------------------------
detect_backend() {
    if [ -n "$BACKEND" ]; then
        return 0
    fi

    if command -v ufw &>/dev/null; then
        BACKEND="ufw"
    elif command -v iptables &>/dev/null; then
        BACKEND="iptables"
    else
        echo "Error: Neither ufw nor iptables found. Install one first."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# UFW setup
# ---------------------------------------------------------------------------
setup_ufw() {
    log_info "Configuring firewall with UFW..."

    # Reset to defaults
    log_rule "Set default deny incoming"
    run_cmd "sudo ufw default deny incoming"

    log_rule "Set default allow outgoing"
    run_cmd "sudo ufw default allow outgoing"

    # Allow standard ports
    for port in "${ALLOW_PORTS[@]}"; do
        log_rule "Allow ${port} (incoming)"
        run_cmd "sudo ufw allow ${port}"
    done

    # Localhost-only ports (UFW uses route rules for this)
    for port in "${LOCALHOST_PORTS[@]}"; do
        local port_num="${port%/*}"
        local proto="${port#*/}"
        log_rule "Allow ${port} from localhost only"
        # Delete any existing broad allow for this port
        run_cmd "sudo ufw delete allow ${port} 2>/dev/null || true"
        # Allow from loopback only
        run_cmd "sudo ufw allow from 127.0.0.1 to any port ${port_num} proto ${proto}"
        run_cmd "sudo ufw allow from ::1 to any port ${port_num} proto ${proto}"
    done

    # Enable UFW
    if [ "$DRY_RUN" != "true" ]; then
        log_rule "Enable UFW"
        sudo ufw --force enable
    else
        log_rule "Enable UFW (would run: sudo ufw --force enable)"
    fi
}

# ---------------------------------------------------------------------------
# iptables setup
# ---------------------------------------------------------------------------
setup_iptables() {
    log_info "Configuring firewall with iptables..."

    # Flush existing rules
    log_rule "Flush existing rules"
    run_cmd "sudo iptables -F INPUT"

    # Default policies
    log_rule "Set default policy: DROP incoming"
    run_cmd "sudo iptables -P INPUT DROP"

    log_rule "Set default policy: ACCEPT outgoing"
    run_cmd "sudo iptables -P OUTPUT ACCEPT"

    log_rule "Set default policy: DROP forward"
    run_cmd "sudo iptables -P FORWARD DROP"

    # Allow established connections
    log_rule "Allow established/related connections"
    run_cmd "sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT"

    # Allow loopback
    log_rule "Allow loopback interface"
    run_cmd "sudo iptables -A INPUT -i lo -j ACCEPT"

    # Allow standard ports
    for port in "${ALLOW_PORTS[@]}"; do
        local port_num="${port%/*}"
        local proto="${port#*/}"
        log_rule "Allow ${port} (incoming)"
        run_cmd "sudo iptables -A INPUT -p ${proto} --dport ${port_num} -j ACCEPT"
    done

    # Localhost-only ports
    for port in "${LOCALHOST_PORTS[@]}"; do
        local port_num="${port%/*}"
        local proto="${port#*/}"
        log_rule "Allow ${port} from localhost only"
        run_cmd "sudo iptables -A INPUT -p ${proto} --dport ${port_num} -s 127.0.0.1 -j ACCEPT"
        run_cmd "sudo iptables -A INPUT -p ${proto} --dport ${port_num} -j DROP"
    done

    # Log and drop everything else
    log_rule "Log dropped packets (rate-limited)"
    run_cmd "sudo iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix 'iptables-dropped: '"

    # Persist rules if iptables-persistent is available
    if [ "$DRY_RUN" != "true" ]; then
        if command -v netfilter-persistent &>/dev/null; then
            log_rule "Persisting iptables rules"
            sudo netfilter-persistent save
        elif command -v iptables-save &>/dev/null; then
            log_rule "Saving iptables rules to /etc/iptables/rules.v4"
            sudo mkdir -p /etc/iptables
            sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null
        else
            log_warn "iptables-persistent not found — rules will not survive reboot"
            log_warn "Install with: sudo apt-get install iptables-persistent"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Display summary
# ---------------------------------------------------------------------------
show_summary() {
    echo ""
    echo "========================================="
    if [ "$DRY_RUN" = "true" ]; then
        echo "  Firewall Rules (DRY RUN — not applied)"
    else
        echo "  Firewall Rules Applied"
    fi
    echo "========================================="
    echo "  Backend:  ${BACKEND}"
    if [ -n "$CC_PROJECT_NAME" ]; then
        echo "  Project:  ${CC_PROJECT_NAME}"
    fi
    echo ""
    echo "  ALLOW incoming:"
    for port in "${ALLOW_PORTS[@]}"; do
        printf "    %-15s %s\n" "$port" "(all sources)"
    done
    echo ""
    echo "  ALLOW incoming (localhost only):"
    for port in "${LOCALHOST_PORTS[@]}"; do
        printf "    %-15s %s\n" "$port" "(127.0.0.1 only)"
    done
    echo ""
    echo "  DEFAULT: deny all other incoming"
    echo "  OUTGOING: allow all"
    echo "========================================="

    if [ "$DRY_RUN" = "true" ]; then
        echo ""
        echo "  This was a dry run. No changes were made."
        echo "  Remove --dry-run to apply these rules."
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "========================================="
echo "  Firewall Setup"
echo "========================================="
if [ "$DRY_RUN" = "true" ]; then
    echo "  Mode: DRY RUN (preview only)"
fi
echo "========================================="
echo ""

detect_backend
log_info "Using firewall backend: ${BACKEND}"
echo ""

case "$BACKEND" in
    ufw)      setup_ufw ;;
    iptables) setup_iptables ;;
    *)
        echo "Error: Unsupported backend '${BACKEND}'. Use 'ufw' or 'iptables'."
        exit 1 ;;
esac

show_summary
