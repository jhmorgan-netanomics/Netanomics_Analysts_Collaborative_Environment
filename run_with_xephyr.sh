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

# Run the Docker container
echo "Starting Docker container with DISPLAY=$DISPLAY"
docker run -it --rm \
    -e DISPLAY=$DISPLAY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    collaborative-env

# Clean up Xephyr when the container exits
echo "Stopping Xephyr..."
kill $XEPHYR_PID
echo "Xephyr process stopped."
