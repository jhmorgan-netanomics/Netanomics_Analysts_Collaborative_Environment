#!/bin/bash

# Usage: ./manage_jupyterlab.sh [elastic_ip] [container_name]

# Path to the virtual environment
VENV_PATH="/home/ubuntu/jupyterlab-env"

# Defaults
DEFAULT_CONTAINER_NAME="collaborative-env"
DEFAULT_ELASTIC_IP="52.70.230.30"

# Parse arguments
ELASTIC_IP=${1:-$DEFAULT_ELASTIC_IP}
CONTAINER_NAME=${2:-$DEFAULT_CONTAINER_NAME}

echo "Using Elastic IP: $ELASTIC_IP"
echo "Container Name: $CONTAINER_NAME"

# Check if the container is running
RUNNING_CONTAINER=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)

if [ -n "$RUNNING_CONTAINER" ]; then
    echo "A running container with the name '$CONTAINER_NAME' exists."
    echo "Stopping the container to avoid conflicts..."
    docker stop "$RUNNING_CONTAINER"
fi

# Check if the container exists (stopped or running)
EXISTING_CONTAINER=$(docker ps -a --filter "name=$CONTAINER_NAME" --quiet)

if [ -n "$EXISTING_CONTAINER" ]; then
    echo "Starting the existing container: $CONTAINER_NAME"
    docker start -ai "$CONTAINER_NAME"
else
    echo "Creating and starting a new container: $CONTAINER_NAME"
    docker run -itd -p 8888:8888 --name "$CONTAINER_NAME" collaborative-env jupyter
fi

# Activate the Python virtual environment
if [ -d "$VENV_PATH" ]; then
    echo "Activating Python virtual environment at $VENV_PATH..."
    source "$VENV_PATH/bin/activate"
    echo "Virtual environment activated. Using Python: $(which python)"
else
    echo "Virtual environment not found at $VENV_PATH. Skipping activation."
fi

# Provide user details to access JupyterLab
echo "JupyterLab started."
echo "Access it at: http://$ELASTIC_IP:8888"
echo "Use the token found in the JupyterLab logs to complete the login."

# Tail the logs for the user to find the token
docker logs -f "$CONTAINER_NAME"
