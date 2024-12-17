import os
from google.cloud import storage

def upload_to_gcs(bucket_name, source_file_path, destination_blob_name):
    """Upload a file to a Google Cloud Storage bucket."""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    blob.upload_from_filename(source_file_path)
    print(f"File {source_file_path} uploaded to {destination_blob_name} in bucket {bucket_name}.")

def download_from_gcs(bucket_name, source_blob_name, destination_file_path):
    """Download a file from a Google Cloud Storage bucket."""
    client = storage.Client()
    bucket = client.bucket(bucket_name)
    blob = bucket.blob(source_blob_name)

    blob.download_to_filename(destination_file_path)
    print(f"File {source_blob_name} downloaded to {destination_file_path}.")

if __name__ == "__main__":
    bucket = os.getenv('GCS_BUCKET')
    upload_to_gcs(bucket, "local_file.txt", "remote_file.txt")

