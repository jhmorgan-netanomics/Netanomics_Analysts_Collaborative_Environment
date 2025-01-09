#!/bin/bash

# Debug: Log current user and environment
echo "DEBUG: Current user: $(whoami)"
echo "DEBUG: Current working directory: $(pwd)"

# Ensure a username is provided
if [[ -z "$1" ]]; then
    echo "Error: No username provided."
    echo "Usage: start_rstudio_server.sh <username>"
    exit 1
fi

# Assign the provided username
username="$1"

# Debug: Validate user existence
if ! id -u "$username" &>/dev/null; then
    echo "Error: User '$username' does not exist. Please create the user first."
    exit 1
fi

# Run the update_rstudio.sh script to ensure configuration is correct
echo "Running update_rstudio.sh for user '$username'..."
/usr/local/bin/update_rstudio.sh "$username"
if [[ $? -ne 0 ]]; then
    echo "Error: update_rstudio.sh failed for user '$username'."
    exit 1
fi

# Start RStudio Server
echo "Starting RStudio Server for user '$username'..."
rstudio-server start
if [[ $? -ne 0 ]]; then
    echo "Error: RStudio Server failed to start."
    exit 1
fi

# Validate that the server has started
if ss -tuln | grep ":8787" &>/dev/null; then
    echo "RStudio Server is running and listening on port 8787."
else
    echo "Error: RStudio Server is not listening on port 8787."
    exit 1
fi

# Tail the RStudio Server logs for debugging
echo "Tailing the RStudio Server logs..."
tail -f /var/log/rstudio-server/rserver.log
