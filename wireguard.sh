#!/usr/bin/env bash
#
# WireGuard VPN setup script
# Modes:
#   --server             Install and configure a WireGuard server
#   --client NAME        Add a new client config (e.g. client1, phone, laptop)
#
# Usage:
#   sudo ./wireguard.sh --server
#   sudo ./wireguard.sh --client client1
#

set -euo pipefail

SERVER_WG_DIR="/etc/wireguard"
SERVER_PRIV_KEY="$SERVER_WG_DIR/private.key"
SERVER_PUB_KEY="$SERVER_WG_DIR/public.key"
SERVER_CONF="$SERVER_WG_DIR/wg0.conf"

print_usage() {
    echo "Usage: $0 [--server | --client NAME]"
    exit 1
}

setup_server() {
    echo "[*] Updating system and installing dependencies..."
    apt update -y
    apt install -y wireguard qrencode ufw

    echo "[*] Generating server keys..."
    if [[ ! -f $SERVER_PRIV_KEY ]]; then
        wg genkey | tee "$SERVER_PRIV_KEY"
        chmod go= "$SERVER_PRIV_KEY"
        cat "$SERVER_PRIV_KEY" | wg pubkey | tee "$SERVER_PUB_KEY"
    else
        echo "[*] Server keys already exist, skipping."
    fi

    echo "[*] Creating server config..."
    cat > "$SERVER_CONF" <<EOF
[Interface]
PrivateKey = $(cat "$SERVER_PRIV_KEY")
Address = 10.8.0.1/24
ListenPort = 51820
SaveConfig = false
EOF

    echo "[*] Enabling IP forwarding..."
    grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p

    PUB_IFACE=$(ip route list default | awk '/default/ {print $5}')
    cat >> "$SERVER_CONF" <<EOF
PostUp = ufw route allow in on wg0 out on $PUB_IFACE
PostUp = iptables -t nat -I POSTROUTING -o $PUB_IFACE -j MASQUERADE
PreDown = ufw route delete allow in on wg0 out on $PUB_IFACE
PreDown = iptables -t nat -D POSTROUTING -o $PUB_IFACE -j MASQUERADE
EOF

    echo "[*] Configuring firewall..."
    ufw allow 51820/udp
    ufw allow OpenSSH
    ufw --force enable

    echo "[*] Enabling WireGuard..."
    systemctl enable wg-quick@wg0
    systemctl restart wg-quick@wg0
    systemctl status wg-quick@wg0 --no-pager
}

setup_client() {
    local CLIENT_NAME=$1
    local CLIENT_PRIV_KEY="$SERVER_WG_DIR/${CLIENT_NAME}_private.key"
    local CLIENT_PUB_KEY="$SERVER_WG_DIR/${CLIENT_NAME}_public.key"
    local CLIENT_CONF="$SERVER_WG_DIR/${CLIENT_NAME}.conf"

    echo "[*] Generating client keys for $CLIENT_NAME..."
    wg genkey | tee "$CLIENT_PRIV_KEY"
    chmod go= "$CLIENT_PRIV_KEY"
    cat "$CLIENT_PRIV_KEY" | wg pubkey | tee "$CLIENT_PUB_KEY"

    echo "[*] Adding client $CLIENT_NAME to server config..."
    cat >> "$SERVER_CONF" <<EOF
[Peer]
PublicKey = $(cat "$CLIENT_PUB_KEY")
AllowedIPs = 10.8.0.$((RANDOM % 200 + 2))/32
EOF

    CLIENT_IP="10.8.0.$((RANDOM % 200 + 2))"

    echo "[*] Creating client config..."
    cat > "$CLIENT_CONF" <<EOF
[Interface]
PrivateKey = $(cat "$CLIENT_PRIV_KEY")
Address = $CLIENT_IP/24
DNS = 1.1.1.1

[Peer]
PublicKey = $(cat "$SERVER_PUB_KEY")
Endpoint = $(curl -s ifconfig.me):51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    echo "[*] Client config for $CLIENT_NAME created at $CLIENT_CONF"
    echo "[*] QR code for mobile import:"
    qrencode -t ansiutf8 < "$CLIENT_CONF"

    echo "[*] Restarting WireGuard to apply changes..."
    systemctl restart wg-quick@wg0
}

# --- main ---
if [[ $# -lt 1 ]]; then
    print_usage
fi

case "$1" in
    --server)
        setup_server
        ;;
    --client)
        if [[ $# -ne 2 ]]; then
            echo "Error: --client requires a NAME"
            print_usage
        fi
        setup_client "$2"
        ;;
    *)
        print_usage
        ;;
esac
