#!/bin/bash

# Start Xephyr
Xephyr :100 -screen 1280x720 &
XEPHYR_PID=$!

# Wait a moment to ensure Xephyr starts
sleep 2

# Check if Xephyr started successfully
if ! ps -p $XEPHYR_PID > /dev/null; then
    echo "Xephyr failed to start. Please check your X11 setup."
    exit 1
fi

# Set the Xephyr DISPLAY
export DISPLAY=:100
echo "Xephyr DISPLAY set to $DISPLAY"

# Allow connections to X server
if ! xhost +local:; then
    echo "Failed to configure xhost. Exiting."
    kill $XEPHYR_PID
    exit 1
fi

# Parse the argument for a container ID or name
CONTAINER_ID=$1
DEFAULT_CONTAINER_NAME="collaborative-env-container"

# Check if a PID or name was provided
if [ -n "$CONTAINER_ID" ]; then
    echo "Checking for specified container: $CONTAINER_ID"
    if docker ps -a --format '{{.ID}} {{.Names}}' | grep -qE "^${CONTAINER_ID}| ${CONTAINER_ID}$"; then
        echo "Attaching to specified container: $CONTAINER_ID"
        docker start -ai $CONTAINER_ID
    else
        echo "Container ID or name $CONTAINER_ID not found. Exiting."
        kill $XEPHYR_PID
        exit 1
    fi
else
    # No container ID provided, default to collaborative-env-container
    echo "No container ID provided. Checking for default container: $DEFAULT_CONTAINER_NAME"
    if docker ps -a --format '{{.Names}}' | grep -q "^${DEFAULT_CONTAINER_NAME}$"; then
        echo "Attaching to existing container: $DEFAULT_CONTAINER_NAME"
        docker start -ai $DEFAULT_CONTAINER_NAME
    else
        echo "Starting a new container: $DEFAULT_CONTAINER_NAME"
        docker run -it --name $DEFAULT_CONTAINER_NAME \
            --env DISPLAY=$DISPLAY \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            collaborative-env
    fi
fi

# Clean up: Kill Xephyr process after the container exits
echo "Stopping Xephyr..."
kill $XEPHYR_PID
echo "Xephyr process stopped."
