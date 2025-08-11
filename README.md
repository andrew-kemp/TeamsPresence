# Teams Presence Keylight

A Python-based service that syncs your Microsoft Teams presence to your Elgato Key Light using Microsoft Graph and the Elgato Key Light API.

## Features

- Runs as a background Linux systemd service
- Authenticates securely to Microsoft Graph via certificate-based authentication
- Monitors Teams presence for a target user (by Object ID)
- Turns your Elgato Key Light on/off depending on your Teams presence (e.g. in a call/meeting)
- Easy unattended install with a Bash script
- All configuration via a simple `.conf` file

## Requirements

- Ubuntu or Debian-based Linux
- Python 3.x
- An Elgato Key Light on your network
- An Azure AD App Registration with certificate authentication and Microsoft Graph API permissions

## Quick Install

Download and run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/andrew-kemp/TeamsPresence/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

The installer will:

- Ensure all system and Python dependencies are present
- Download the latest source code and requirements
- Generate a self-signed certificate for Azure authentication
- Prompt you for:
  - Azure Tenant ID
  - Azure Client ID (App Registration)
  - Teams User ID (Object ID)
  - Elgato Key Light IP address
- Create a config file at `/opt/teams-keylight/teams-keylight.conf`
- Save the certificate in `/opt/teams-keylight/keylightair.pem`
- Save a public certificate for Azure upload at `/opt/teams-keylight/keylightair-upload.crt`
- Install and start a systemd service

**IMPORTANT:**  
After install, you must upload `/opt/teams-keylight/keylightair-upload.crt` to your Azure App Registration under **Certificates & secrets** → **Certificates**.

## Azure App Registration Setup

1. Go to **Azure Portal** → **Azure Active Directory** → **App registrations**
2. Register a new app (or open your existing one)
3. Under **Certificates & secrets > Certificates**, upload `/opt/teams-keylight/keylightair-upload.crt`
4. Assign the `Presence.Read` Microsoft Graph API permission (application type), and grant admin consent

## Configuration

Configuration is stored in `/opt/teams-keylight/teams-keylight.conf`:

```ini
TENANT_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
CLIENT_ID=yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
USER_ID=zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz
KEYLIGHT_IP=192.168.200.111
PEM_PATH=/opt/teams-keylight/keylightair.pem
```

- To change config, edit the file and restart the service:  
  `sudo systemctl restart teams-keylight`

## Service Commands

- Check status:  
  `sudo systemctl status teams-keylight`
- View logs:  
  `sudo journalctl -u teams-keylight -f`
- Restart:  
  `sudo systemctl restart teams-keylight`
- Stop:  
  `sudo systemctl stop teams-keylight`

## Uninstall

To remove the service and files:

```bash
sudo systemctl disable --now teams-keylight
sudo rm -rf /opt/teams-keylight
sudo rm /etc/systemd/system/teams-keylight.service
sudo systemctl daemon-reload
```

## Troubleshooting

- If authentication fails, make sure you have uploaded the **current** certificate to Azure and that permissions are correct.
- The certificate's thumbprint printed on startup must match that shown in the Azure Portal.
- If you re-run the installer (and thus re-generate the certificate), you must upload the new `.crt` file to Azure.

## License

MIT

## Author

Andrew Kemp <andrew@kemponline.co.uk>
