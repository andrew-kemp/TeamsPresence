#!/bin/bash

set -e

INSTALL_DIR="/opt/teams-keylight"
SERVICE_NAME="teams-keylight"
SCRIPT_NAME="teams_presence.py"
VENV_DIR="$INSTALL_DIR/venv"
CERT_FILE="$INSTALL_DIR/keylightair.pem"
SYSTEMD_PATH="/etc/systemd/system/${SERVICE_NAME}.service"
KEYLIGHT_IP_DEFAULT="192.168.200.111"

echo "==== Teams Keylight Install Script ===="

# 1. Create the install directory
if [ ! -d "$INSTALL_DIR" ]; then
    sudo mkdir -p "$INSTALL_DIR"
    sudo chown $USER:$USER "$INSTALL_DIR"
fi

# 2. Copy Python script
if [ -f "$SCRIPT_NAME" ]; then
    cp "$SCRIPT_NAME" "$INSTALL_DIR/"
else
    echo "ERROR: $SCRIPT_NAME not found in the current directory."
    exit 1
fi

# 3. Setup virtual environment
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

# 4. Install requirements in venv
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install azure-identity cryptography requests

# 5. Install certificate
if [ ! -f "$CERT_FILE" ]; then
    echo "Please enter the path to your PEM certificate file (keylightair.pem):"
    read -r CERTSOURCE
    if [ -f "$CERTSOURCE" ]; then
        cp "$CERTSOURCE" "$CERT_FILE"
        echo "Certificate installed."
    else
        echo "Certificate file not found! Please copy your PEM file to $CERT_FILE manually."
        echo "Install will continue, but the service will NOT work until the cert is present."
    fi
else
    echo "Certificate already present at $CERT_FILE"
fi

# 6. Prompt for Teams/Azure info if not present in env file
ENV_FILE="$INSTALL_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "Please provide the following Azure/Teams settings."
    read -p "Azure Tenant ID: " TENANT_ID
    read -p "Azure Client ID: " CLIENT_ID
    read -p "Teams User ID (Object ID): " USER_ID
    read -p "Elgato Key Light IP [default: $KEYLIGHT_IP_DEFAULT]: " KEYLIGHT_IP
    KEYLIGHT_IP=${KEYLIGHT_IP:-$KEYLIGHT_IP_DEFAULT}
    cat > "$ENV_FILE" <<EOF
TENANT_ID=$TENANT_ID
CLIENT_ID=$CLIENT_ID
USER_ID=$USER_ID
KEYLIGHT_IP=$KEYLIGHT_IP
PEM_PATH=$CERT_FILE
EOF
    echo "Configuration written to $ENV_FILE"
else
    echo "Config file already exists at $ENV_FILE"
fi

# 7. Create systemd service
cat <<EOF | sudo tee "$SYSTEMD_PATH" > /dev/null
[Unit]
Description=Teams Presence Keylight Controller
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$INSTALL_DIR
EnvironmentFile=$ENV_FILE
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
echo "Check status with: sudo systemctl status $SERVICE_NAME"
echo "Logs: journalctl -u $SERVICE_NAME -f"
