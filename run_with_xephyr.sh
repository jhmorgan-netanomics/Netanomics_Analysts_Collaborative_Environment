#!/bin/bash

set -e  # Exit on any error

# Detect the active host DISPLAY
HOST_DISPLAY=${DISPLAY}
if [ -z "$HOST_DISPLAY" ]; then
    echo "No active DISPLAY found on the host. Ensure X11 is running."
    exit 1
fi
echo "Detected host DISPLAY: $HOST_DISPLAY"

# Allow connections to the host X server
if ! xhost + &>/dev/null; then
    echo "Failed to configure xhost. Exiting."
    exit 1
fi

# Dynamically assign Xephyr DISPLAY
for DISPLAY_NUMBER in $(seq 100 110); do
    if [ ! -e /tmp/.X${DISPLAY_NUMBER}-lock ]; then
        export XEphyr_DISPLAY=:$DISPLAY_NUMBER
        echo "Assigned Xephyr DISPLAY: $XEphyr_DISPLAY"
        break
    fi
done

if [ -z "$XEphyr_DISPLAY" ]; then
    echo "No available Xephyr DISPLAY found. Exiting."
    exit 1
fi

# Start Xephyr
Xephyr $XEphyr_DISPLAY -screen 1280x720 &
XEPHYR_PID=$!
trap 'kill $XEPHYR_PID' EXIT  # Ensure Xephyr is cleaned up on script exit

# Wait for Xephyr to initialize
sleep 2

# Verify Xephyr started successfully
if ! ps -p $XEPHYR_PID > /dev/null; then
    echo "Xephyr failed to start. Please check your X11 setup."
    exit 1
fi

# Set Xephyr DISPLAY for container
export DISPLAY=$XEphyr_DISPLAY
echo "Xephyr DISPLAY set for container: $DISPLAY"

# Container name (default or provided as argument)
CONTAINER_NAME=${1:-"collaborative-env-xephyr"}

# Check if the container is running
RUNNING_CONTAINER=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)

if [ -n "$RUNNING_CONTAINER" ]; then
    echo "Attaching to the running container: $CONTAINER_NAME"
    docker exec -it "$CONTAINER_NAME" bash
    exit 0
fi

# Check if the container exists (but is stopped)
EXISTING_CONTAINER=$(docker ps -a --filter "name=$CONTAINER_NAME" --quiet)

if [ -n "$EXISTING_CONTAINER" ]; then
    echo "Starting the existing container: $CONTAINER_NAME"
    docker start "$CONTAINER_NAME"
    docker exec -it "$CONTAINER_NAME" bash
    exit 0
fi

# Run a new Docker container if no matching container exists
echo "Creating and starting a new container: $CONTAINER_NAME"
docker run -it --rm \
    --name "$CONTAINER_NAME" \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    collaborative-env

# Clean up Xephyr when the container exits
echo "Stopping Xephyr..."
kill $XEPHYR_PID
echo "Xephyr process stopped."
