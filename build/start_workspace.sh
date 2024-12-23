#!/bin/bash

# Debug: Print the value of DISPLAY
echo "DEBUG: Current DISPLAY is: '${DISPLAY}'"

# Check and configure Git user.name
if ! git config --global user.name &> /dev/null; then
    echo "Git user.name is not set. Please enter your Git username:"
    read git_user_name
    git config --global user.name "$git_user_name"
fi

# Check and configure Git user.email
if ! git config --global user.email &> /dev/null; then
    echo "Git user.email is not set. Please enter your Git email:"
    read git_user_email
    git config --global user.email "$git_user_email"
fi

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


