from dropbox_utils import initialize_dropbox, dropbox_scan, dropbox_upload, dropbox_download

# Initialize Dropbox client
try:
    dbx = initialize_dropbox()
    print("Dropbox client initialized. You can now use dropbox_scan, dropbox_upload, and dropbox_download.")
except Exception as e:
    print("Error during Dropbox setup:", e)

