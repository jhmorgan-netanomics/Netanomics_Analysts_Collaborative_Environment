from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build
import os

# Path to your OAuth Client ID JSON file
CREDENTIALS_PATH = "/root/.config/google_credentials/google_credentials.json"

# Scopes: Allows read/write access to Google Drive files
SCOPES = ['https://www.googleapis.com/auth/drive.file']

def authenticate_google_drive():
    """Authenticate user using OAuth Client ID, supporting both browser and console flows."""
    flow = InstalledAppFlow.from_client_secrets_file(CREDENTIALS_PATH, SCOPES)

    try:
        # Attempt to use a browser-based flow
        print("Attempting browser-based OAuth flow...")
        creds = flow.run_local_server(port=8080)
    except Exception as e:
        print(f"Browser-based flow failed: {e}")
        print("Please visit the following URL to authorize the application, then paste the code here:")
        auth_url, _ = flow.authorization_url()
        print(auth_url)

        # Prompt user to paste the authorization code
        code = input("Enter the authorization code: ")
        creds = flow.fetch_token(code=code)

    service = build('drive', 'v3', credentials=creds)
    return service

def list_drive_files(service):
    """List the first 10 files in Google Drive."""
    print("Retrieving Google Drive files...")
    results = service.files().list(
        pageSize=10, fields="files(id, name)"
    ).execute()
    items = results.get('files', [])

    if not items:
        print("No files found.")
    else:
        for item in items:
            print(f"{item['name']} ({item['id']})")

if __name__ == "__main__":
    print("Starting OAuth flow for Google Drive...")
    drive_service = authenticate_google_drive()
    list_drive_files(drive_service)

