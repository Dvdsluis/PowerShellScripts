import os
import argparse
from azure.storage.blob import BlobServiceClient
from dotenv import load_dotenv
from image_analyzer import analyze_image_file

load_dotenv()

BLOB_CONNECTION_STRING = os.getenv('BLOB_CONNECTION_STRING')
BLOB_CONTAINER = os.getenv('BLOB_CONTAINER')
TREE_FOLDER = 'tree-pictures/'
VIDEO_EXTENSIONS = {'.mp4', '.mov', '.avi', '.mkv', '.webm'}

# --- Utility Functions ---
def is_video(filename):
    """Check if the file is a video based on its extension."""
    return os.path.splitext(filename)[1].lower() in VIDEO_EXTENSIONS

def upload_local_images(local_dir):
    """Upload all non-video files from a local directory to Azure Blob Storage."""
    blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
    container_client = blob_service_client.get_container_client(BLOB_CONTAINER)
    for fname in os.listdir(local_dir):
        fpath = os.path.join(local_dir, fname)
        if os.path.isfile(fpath) and not is_video(fname):
            print(f"Uploading {fname} to blob storage...")
            with open(fpath, "rb") as data:
                container_client.upload_blob(fname, data, overwrite=True)

# --- Cleaning Step ---
def clean_blob_storage():
    """Delete all blobs not in the tree-pictures/ folder from the container."""
    blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
    container_client = blob_service_client.get_container_client(BLOB_CONTAINER)
    blobs = list(container_client.list_blobs())
    for blob in blobs:
        # Only delete blobs that are not in the tree-pictures/ folder
        if not blob.name.startswith(TREE_FOLDER):
            print(f"Deleting blob: {blob.name}")
            container_client.delete_blob(blob.name)
    print("Blob container cleaned. Only tree-pictures/ folder remains.")

# --- Analyze and Move Step ---
def analyze_and_move_blobs(keywords):
    """Analyze blobs and move those containing keywords to the tree-pictures/ folder."""
    blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
    container_client = blob_service_client.get_container_client(BLOB_CONTAINER)
    blobs = [blob for blob in container_client.list_blobs() if not blob.name.startswith(TREE_FOLDER)]
    for blob in blobs:
        blob_name = blob.name
        if is_video(blob_name):
            print(f"Skipping video: {blob_name}")
            continue
        temp_path = f"temp_{os.path.basename(blob_name)}"
        with open(temp_path, "wb") as f:
            f.write(container_client.get_blob_client(blob_name).download_blob().readall())
        found = False
        for keyword in keywords:
            tags = analyze_image_file(temp_path, search_term=keyword)
            if tags and any(kw in tag.lower() for tag in tags for kw in keywords):
                move_blob_to_tree_folder(blob_name)
                found = True
                break
        if not found:
            print(f"No target keywords found in {blob_name}")
        os.remove(temp_path)

def move_blob_to_tree_folder(blob_name):
    blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
    source_blob = f"https://{blob_service_client.account_name}.blob.core.windows.net/{BLOB_CONTAINER}/{blob_name}"
    tree_blob_name = TREE_FOLDER + os.path.basename(blob_name)
    container_client = blob_service_client.get_container_client(BLOB_CONTAINER)
    container_client.get_blob_client(tree_blob_name).start_copy_from_url(source_blob)
    print(f"Moved {blob_name} to {tree_blob_name}")

# --- Download Step ---
def download_tree_media(local_dir="downloaded_tree_media"):
    """Download all files from the tree-pictures/ folder in blob storage to a local directory."""
    os.makedirs(local_dir, exist_ok=True)
    blob_service_client = BlobServiceClient.from_connection_string(BLOB_CONNECTION_STRING)
    container_client = blob_service_client.get_container_client(BLOB_CONTAINER)
    blobs = [blob for blob in container_client.list_blobs() if blob.name.startswith(TREE_FOLDER)]
    print(f"Found {len(blobs)} files in {TREE_FOLDER}")
    for blob in blobs:
        blob_name = blob.name
        filename = os.path.basename(blob_name)
        local_path = os.path.join(local_dir, filename)
        print(f"Downloading {blob_name} to {local_path}")
        with open(local_path, "wb") as f:
            f.write(container_client.get_blob_client(blob_name).download_blob().readall())
    print("Download complete.")

# --- Main CLI ---
def main():
    parser = argparse.ArgumentParser(description="Azure AI Tree Image Pipeline")
    parser.add_argument('--upload', type=str, help='Local directory to upload images from')
    parser.add_argument('--clean', action='store_true', help='Clean non-tree blobs from container before processing')
    parser.add_argument('--analyze', action='store_true', help='Analyze blobs and move tree images to tree-pictures/')
    parser.add_argument('--download', type=str, help='Local directory to download tree images/videos to')
    parser.add_argument('--keywords', nargs='+', default=['tree'], help='Keywords to detect in images (default: tree)')
    args = parser.parse_args()

    if args.upload:
        upload_local_images(args.upload)
    if args.clean:
        clean_blob_storage()
    if args.analyze:
        analyze_and_move_blobs(args.keywords)
    if args.download:
        download_tree_media(args.download)

if __name__ == "__main__":
    main()
