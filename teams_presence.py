import time
import requests
import os
from azure.identity import CertificateCredential
from cryptography.hazmat.primitives import hashes
from cryptography import x509

def getenv_required(var):
    value = os.getenv(var)
    if not value:
        raise ValueError(f"Environment variable {var} not set.")
    return value

PEM_PATH = getenv_required("PEM_PATH")
TENANT_ID = getenv_required("TENANT_ID")
CLIENT_ID = getenv_required("CLIENT_ID")
USER_ID = getenv_required("USER_ID")
KEYLIGHT_IP = getenv_required("KEYLIGHT_IP")

def print_cert_thumbprint(pem_path):
    with open(pem_path, "rb") as f:
        lines = f.readlines()
    cert_lines = []
    in_cert = False
    for line in lines:
        if b"BEGIN CERTIFICATE" in line:
            in_cert = True
        if in_cert:
            cert_lines.append(line)
        if b"END CERTIFICATE" in line:
            break
    cert_data = b"".join(cert_lines)
    cert = x509.load_pem_x509_certificate(cert_data)
    thumbprint = cert.fingerprint(hashes.SHA1()).hex().upper()
    print("Loaded certificate thumbprint:", thumbprint)
    return thumbprint

def get_token():
    credential = CertificateCredential(
        tenant_id=TENANT_ID,
        client_id=CLIENT_ID,
        certificate_path=PEM_PATH,
    )
    token = credential.get_token("https://graph.microsoft.com/.default")
    return token.token

def get_presence(access_token):
    url = f"https://graph.microsoft.com/v1.0/users/{USER_ID}/presence"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json"
    }
    response = requests.get(url, headers=headers)
    try:
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"Error calling presence API: {e}")
        print(f"Response: {response.status_code} {response.text}")
        return None

def keylight_set_on(on: bool):
    url = f"http://{KEYLIGHT_IP}:9123/elgato/lights"
    payload = {"lights": [{"on": 1 if on else 0}]}
    try:
        resp = requests.put(url, json=payload, timeout=2)
        resp.raise_for_status()
        print(f"Key Light {'ON' if on else 'OFF'}")
    except Exception as e:
        print(f"Could not set Key Light: {e}")

def main():
    print_cert_thumbprint(PEM_PATH)
    access_token = get_token()
    last_status = None
    token_expiry = time.time() + 3300

    while True:
        if time.time() > token_expiry:
            access_token = get_token()
            token_expiry = time.time() + 3300

        presence = get_presence(access_token)
        if presence is not None:
            availability = presence.get("availability", "PresenceUnknown")
            activity = presence.get("activity", "PresenceUnknown")
            print(f"Current presence: {availability} / {activity}")

            in_call = activity.lower() in ["inacall", "inaudiocall", "inmeeting", "presenting"]
            light_on = in_call
            if light_on != last_status:
                keylight_set_on(light_on)
                last_status = light_on
        else:
            print("Could not fetch presence.")

        time.sleep(5)

if __name__ == "__main__":
    main()
