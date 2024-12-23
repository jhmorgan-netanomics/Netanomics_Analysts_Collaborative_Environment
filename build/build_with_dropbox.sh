#!/bin/bash

# Define paths
DOCKER_BUILD_DIR=$(pwd)
DROPBOX_KEYS="$DOCKER_BUILD_DIR/dropbox_keys.json"
GOOGLE_KEYS="$DOCKER_BUILD_DIR/google_credentials.json"

# Default values for build flags
NO_CACHE_FLAG=""
TAG_NAME="collaborative-env"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-cache)
            NO_CACHE_FLAG="--no-cache"
            echo "Building with no cache..."
            shift
            ;;
        -t|--tag)
            if [[ -n $2 ]]; then
                TAG_NAME="$2"
                echo "Using tag name: $TAG_NAME"
                shift 2
            else
                echo "Error: --tag flag requires an argument."
                exit 1
            fi
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check for dropbox_keys.json
if [ -f "$DROPBOX_KEYS" ]; then
    echo "Dropbox keys found. Proceeding with integration..."
else
    echo "Dropbox keys not found. Creating a placeholder for build."
    cp /dev/null "$DROPBOX_KEYS"
    DROPBOX_PLACEHOLDER_CREATED=true
fi

# Check for google_credentials.json
if [ -f "$GOOGLE_KEYS" ]; then
    echo "Google credentials found. Proceeding with integration..."
else
    echo "Google credentials not found. Creating a placeholder for build."
    cp /dev/null "$GOOGLE_KEYS"
    GOOGLE_PLACEHOLDER_CREATED=true
fi

# Build the Docker image
echo "Building Docker image '$TAG_NAME'..."
docker build $NO_CACHE_FLAG -t "$TAG_NAME" .

# Clean up placeholders if they were created
if [ "$DROPBOX_PLACEHOLDER_CREATED" = true ]; then
    echo "Removing placeholder dropbox_keys.json..."
    rm "$DROPBOX_KEYS"
fi

if [ "$GOOGLE_PLACEHOLDER_CREATED" = true ]; then
    echo "Removing placeholder google_credentials.json..."
    rm "$GOOGLE_KEYS"
fi

# Run the Docker container with volume mounts for Julia, Python, and R caches
echo "Running the Docker container with persistent caches for Julia, Python, and R..."

JULIA_CACHE="$HOME/.julia"
PYTHON_CACHE="$HOME/.cache/pip"
R_CACHE="$HOME/.cache/R"

# Create the cache directories if they don't exist
mkdir -p "$JULIA_CACHE" "$PYTHON_CACHE" "$R_CACHE"

docker run \
    -v "$JULIA_CACHE:/root/.julia" \
    -v "$PYTHON_CACHE:/root/.cache/pip" \
    -v "$R_CACHE:/root/.cache/R" \
    -it "$TAG_NAME" /bin/bash

