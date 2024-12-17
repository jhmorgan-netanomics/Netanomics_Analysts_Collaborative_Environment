#!/bin/bash

# Debug: Print the value of DISPLAY
echo "DEBUG: Current DISPLAY is: '${DISPLAY}'"

# Check if the first argument is "jupyter"
if [ "$1" == "jupyter" ]; then
    echo "Starting JupyterLab..."
    /usr/local/bin/start_jupyterlab.sh
elif [ -n "$DISPLAY" ]; then
    echo "Using existing DISPLAY: $DISPLAY"

    # Start Openbox for X11 workflows
    echo "Starting Openbox session..."
    openbox &
    exec /bin/bash
else
    echo "No DISPLAY found. Starting a basic interactive shell..."
    exec /bin/bash
fi

