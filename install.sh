#!/bin/bash

set -e

INSTALL_DIR="/opt/teams-keylight"
SERVICE_NAME="teams-keylight"
SCRIPT_NAME="teams_presence.py"
RAW_URL="https://raw.githubusercontent.com/andrew-kemp/TeamsPresence/refs/heads/main/teams_presence.py"
VENV_DIR="$INSTALL_DIR/venv"
CERT_FILE="$INSTALL_DIR/keylightair.pem"
CONF_FILE="$INSTALL_DIR/teams-keylight.conf"
SYSTEMD_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

echo_title() {
    echo; echo "=============================="
    echo "$@"
    echo "=============================="
}

# 1. System dependencies
echo_title "Checking/installing dependencies"
if ! command -v python3 &>/dev/null; then
    sudo apt-get update
    sudo apt-get install -y python3
fi
if ! dpkg -s python3-venv &>/dev/null; then
    sudo apt-get install -y python3-venv
fi
if ! command -v curl &>/dev/null; then
    sudo apt-get install -y curl
fi
if ! command -v openssl &>/dev/null; then
    sudo apt-get install -y openssl
fi

# 2. Create install directory
echo_title "Setting up directories"
sudo mkdir -p "$INSTALL_DIR"
sudo chown $USER:$USER "$INSTALL_DIR"

# 3. Download script
echo_title "Downloading script"
curl -fsSL "$RAW_URL" -o "$INSTALL_DIR/$SCRIPT_NAME"
chmod 700 "$INSTALL_DIR/$SCRIPT_NAME"

# 4. Set up venv
echo_title "Setting up Python virtual environment"
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi
"$VENV_DIR/bin/pip" install --upgrade pip
"$VENV_DIR/bin/pip" install azure-identity cryptography requests

# 5. Generate self-signed certificate (always overwrite for idempotency)
echo_title "Generating self-signed certificate"
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout "$INSTALL_DIR/keylightair.key" \
    -out "$INSTALL_DIR/keylightair.crt" \
    -subj "/CN=teams-keylight"
cat "$INSTALL_DIR/keylightair.key" "$INSTALL_DIR/keylightair.crt" > "$CERT_FILE"
chmod 600 "$INSTALL_DIR/keylightair.key" "$INSTALL_DIR/keylightair.crt" "$CERT_FILE"
echo "Certificate and PEM created at $CERT_FILE"

# 6. Display public cert for Azure
echo_title "Azure App Registration Certificate Block"
awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/ {print}' "$INSTALL_DIR/keylightair.crt"

# 7. Prompt for config and write conf file
echo_title "Configuring Teams Keylight"
read -p "Azure Tenant ID: " TENANT_ID
read -p "Azure Client ID: " CLIENT_ID
read -p "Teams User ID (Object ID): " USER_ID
read -p "Elgato Key Light IP [192.168.200.111]: " KEYLIGHT_IP
KEYLIGHT_IP=${KEYLIGHT_IP:-192.168.200.111}

cat > "$CONF_FILE" <<EOF
TENANT_ID=$TENANT_ID
CLIENT_ID=$CLIENT_ID
USER_ID=$USER_ID
KEYLIGHT_IP=$KEYLIGHT_IP
PEM_PATH=$CERT_FILE
EOF
chmod 600 "$CONF_FILE"
echo "Config written to $CONF_FILE"

# 8. Create systemd service
cat <<EOF | sudo tee "$SYSTEMD_PATH" > /dev/null
[Unit]
Description=Teams Presence Keylight Controller
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$CONF_FILE
ExecStart=$VENV_DIR/bin/python $INSTALL_DIR/$SCRIPT_NAME
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now "$SERVICE_NAME"

echo
echo "==== Install complete! ===="
echo "Teams-Keylight will now start automatically on boot."
echo "Check status: sudo systemctl status $SERVICE_NAME"
echo "Logs:       sudo journalctl -u $SERVICE_NAME -f"
