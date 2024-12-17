#!/bin/bash

# Path to the workspace
WORKSPACE_PATH="/workspace"

echo "Starting JupyterLab in the container..."
jupyter-lab --ip=0.0.0.0 --no-browser --allow-root --notebook-dir="$WORKSPACE_PATH"
