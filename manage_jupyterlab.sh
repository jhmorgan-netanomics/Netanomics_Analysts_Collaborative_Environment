#!/bin/bash

# Path to the virtual environment
VENV_PATH="/home/ubuntu/jupyterlab-env"

# Defaults
DEFAULT_CONTAINER_NAME="collaborative-env"
DEFAULT_ELASTIC_IP="52.70.230.30"

# Parse arguments
COMMAND=$1
CONTAINER_NAME=${2:-$DEFAULT_CONTAINER_NAME}
ELASTIC_IP=${3:-$DEFAULT_ELASTIC_IP}

if [ "$COMMAND" == "initialize" ]; then
    echo "Using provided Elastic IP: $ELASTIC_IP"

    # Stop any running container with the same name
    EXISTING_CONTAINER=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)
    if [ -n "$EXISTING_CONTAINER" ]; then
        echo "Stopping and removing the container: $EXISTING_CONTAINER"
        docker stop "$EXISTING_CONTAINER"
        docker rm "$EXISTING_CONTAINER"
    fi

    # Check for processes using port 8888 and kill them if necessary
    PORT_PID=$(lsof -ti:8888)
    if [ -n "$PORT_PID" ]; then
        echo "Killing process on port 8888: $PORT_PID"
        kill -9 "$PORT_PID"
    fi

    # Start the container
    echo "Starting a new container named '$CONTAINER_NAME'..."
    docker run -itd -p 8888:8888 --name "$CONTAINER_NAME" collaborative-env jupyter
    CONTAINER_ID=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)

    echo "Activating Python virtual environment at $VENV_PATH..."
    source $VENV_PATH/bin/activate
    echo "Virtual environment activated. Using Python: $(which python)"

    # Retrieve the JupyterLab token
    echo "Fetching JupyterLab token..."
    sleep 5  # Allow time for JupyterLab to initialize
    TOKEN=$(docker logs "$CONTAINER_ID" 2>&1 | grep -oP "token=\K[^&]+")
    if [ -n "$TOKEN" ]; then
        echo "JupyterLab started. Access it at: http://$ELASTIC_IP:8888/lab?token=$TOKEN"
    else
        echo "Failed to retrieve JupyterLab token. Check the container logs for details."
    fi

elif [ "$COMMAND" == "start" ]; then
    # Start an existing container
    echo "Attaching to the running container: $CONTAINER_NAME"
    docker exec -it "$CONTAINER_NAME" bash
else
    echo "Invalid command. Usage: ./manage_jupyterlab.sh {initialize|start} [container_name] [elastic_ip]"
fi

