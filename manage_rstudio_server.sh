#!/bin/bash

# Usage: ./manage_rstudio_server.sh [container_name] [ip_address] [port]

# Defaults
DEFAULT_CONTAINER_NAME="collaborative-env-rstudio"
DEFAULT_IP="127.0.0.1"
DEFAULT_PORT="8787"

# Parse arguments
CONTAINER_NAME=${1:-$DEFAULT_CONTAINER_NAME}
IP=${2:-$DEFAULT_IP}
PORT=${3:-$DEFAULT_PORT}

echo "Managing RStudio Server for container: $CONTAINER_NAME on IP: $IP and port: $PORT"

# Function to check if a port is in use and free it
check_and_free_port() {
    local port_to_check=$1
    local pid
    pid=$(lsof -ti :"$port_to_check")
    if [ -n "$pid" ]; then
        echo "Port $port_to_check is already in use by PID $pid. Terminating the process..."
        kill -9 "$pid"
        echo "Freed port $port_to_check."
    fi
}

# Free the specified port
check_and_free_port "$PORT"

# Check if the container is running
RUNNING_CONTAINER=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)

if [ -n "$RUNNING_CONTAINER" ]; then
    echo "A running container with the name '$CONTAINER_NAME' exists."
    echo "Attaching to the container to start RStudio Server..."
    docker exec -it "$CONTAINER_NAME" /usr/local/bin/start_rstudio_server.sh
    exit 0
fi

# Check if the container exists (stopped or running)
EXISTING_CONTAINER=$(docker ps -a --filter "name=$CONTAINER_NAME" --quiet)

if [ -n "$EXISTING_CONTAINER" ]; then
    echo "Starting the existing container: $CONTAINER_NAME"
    docker start "$CONTAINER_NAME"
    echo "Attaching to the container to start RStudio Server..."
    docker exec -it "$CONTAINER_NAME" /usr/local/bin/start_rstudio_server.sh
    exit 0
fi

# If no container exists, create a new one
echo "Creating and starting a new container: $CONTAINER_NAME on port $PORT"
docker run -itd -p "$PORT:8787" --name "$CONTAINER_NAME" collaborative-env

# Verify the container creation
if [ $? -eq 0 ]; then
    echo "Container $CONTAINER_NAME created successfully."
    echo "Attaching to the container to initialize RStudio Server..."
    docker exec -it "$CONTAINER_NAME" /usr/local/bin/start_workspace.sh rstudio
else
    echo "Error: Failed to create the container $CONTAINER_NAME."
    exit 1
fi
