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
xhost +local: || { echo "Failed to configure xhost. Exiting."; kill $XEPHYR_PID; exit 1; }

# Check if the Docker container exists
CONTAINER_NAME="collaborative-env-container"

if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Attaching to existing container: $CONTAINER_NAME"
    docker start -ai $CONTAINER_NAME
else
    echo "Starting a new container: $CONTAINER_NAME"
    docker run -it --name $CONTAINER_NAME --env DISPLAY=$DISPLAY -v /tmp/.X11-unix:/tmp/.X11-unix collaborative-env
fi

# Clean up: Kill Xephyr process after the container exits
echo "Stopping Xephyr..."
kill $XEPHYR_PID

