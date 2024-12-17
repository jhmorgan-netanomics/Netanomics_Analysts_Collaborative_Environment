import dropbox
import json
import os

# Path to Dropbox keys in the secure location
KEYS_PATH = "/root/.config/dropbox_keys/dropbox_keys.json"

# Initialize the Dropbox client
def initialize_dropbox():
    """Initialize Dropbox client using stored keys."""
    if not os.path.exists(KEYS_PATH):
        raise FileNotFoundError("Dropbox keys not found.")
    
    with open(KEYS_PATH, "r") as f:
        keys = json.load(f)
    
    flow = dropbox.DropboxOAuth2FlowNoRedirect(keys["app_key"], keys["app_secret"])
    auth_url = flow.start()
    print("1. Go to:", auth_url)
    print("2. Click 'Allow' (you might need to log in first).")
    print("3. Copy the authorization code.")
    
    auth_code = input("Enter the authorization code here: ").strip()
    result = flow.finish(auth_code)
    access_token = result.access_token
    print("Access token obtained successfully:", access_token)
    
    return dropbox.Dropbox(access_token)


# Define utility functions
def dropbox_scan(dbx, folder_path="/"):
    """List contents of a folder in Dropbox."""
    try:
        # Convert "/" to an empty string for root folder
        folder_path = "" if folder_path == "/" else folder_path
        print(f"\nContents of folder '{folder_path or '/'}':")
        for entry in dbx.files_list_folder(folder_path).entries:
            print(entry.name)
    except Exception as e:
        print("Error listing folder contents:", e)

def dropbox_upload(dbx, local_file, dropbox_path):
    """Upload a local file to Dropbox."""
    try:
        with open(local_file, "rb") as f:
            dbx.files_upload(f.read(), dropbox_path, mode=dropbox.files.WriteMode.overwrite)
        print(f"File uploaded successfully to {dropbox_path}")
    except Exception as e:
        print("Error uploading file:", e)


def dropbox_download(dbx, dropbox_path, local_file):
    """Download a file from Dropbox."""
    try:
        with open(local_file, "wb") as f:
            metadata, res = dbx.files_download(path=dropbox_path)
            f.write(res.content)
        print(f"File downloaded successfully to {local_file}")
    except Exception as e:
        print("Error downloading file:", e)

