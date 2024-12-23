from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
import os
import socket

# Path to your OAuth Client ID JSON file
CREDENTIALS_PATH = "/root/.config/google_credentials/google_credentials.json"

# Scopes: Allows read/write access to Google Drive files
SCOPES = ['https://www.googleapis.com/auth/drive.file']

def authenticate_google_drive():
    """Authenticate user using OAuth Client ID, supporting both browser and console flows."""
    flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_PATH, SCOPES)

    try:
        # Check if port 8080 is available before attempting the browser-based flow
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("localhost", 8080)) == 0:
                print("Port 8080 is in use. Trying port 9090...")
                port = 9090
            else:
                port = 8080

        # Attempt to use a browser-based flow
        print(f"Attempting browser-based OAuth flow on port {port}...")
        creds = flow.run_local_server(port=port, open_browser=False, redirect_uri='https://netanomicscollab.jhmorgan-phd-compsocialpsych.net/')
        print("Browser-based OAuth flow successful.")

    except Exception as e:
        print(f"Browser-based flow failed: {e}")
        print("Falling back to manual authentication flow.")
        try:
            auth_url, _ = flow.authorization_url(prompt='consent')
            print("Please visit the following URL to authorize the application:")
            print(auth_url)

            # Prompt user to paste the authorization code
            code = input("Enter the authorization code: ")
            creds = flow.fetch_token(code=code)
            print("Manual OAuth flow successful.")
        except Exception as e:
            print(f"Manual OAuth flow failed: {e}")
            return None

    service = build('drive', 'v3', credentials=creds)
    return service

def list_drive_files(service):
    """List the first 10 files in Google Drive."""
    if service is None:
        print("Service not initialized. Exiting...")
        return

    print("Retrieving Google Drive files...")
    try:
        results = service.files().list(
            pageSize=10, fields="files(id, name)"
        ).execute()
        items = results.get('files', [])

        if not items:
            print("No files found.")
        else:
            print("Files found:")
            for item in items:
                print(f"{item['name']} ({item['id']})")
    except Exception as e:
        print(f"Error retrieving files: {e}")

if __name__ == "__main__":
    print("Starting OAuth flow for Google Drive...")
    drive_service = authenticate_google_drive()
    list_drive_files(drive_service)

