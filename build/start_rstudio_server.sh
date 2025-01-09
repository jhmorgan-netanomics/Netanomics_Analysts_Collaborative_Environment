#!/bin/bash

# Extract the server-user from rserver.conf
configured_user=$(grep "^server-user=" /etc/rstudio/rserver.conf | cut -d '=' -f2)

# Check if the server-user is set
if [[ -z "$configured_user" ]]; then
    echo "Error: No server-user found in /etc/rstudio/rserver.conf."
    exit 1
fi

# Ensure the user exists
if ! id -u "$configured_user" &>/dev/null; then
    echo "Error: User '$configured_user' does not exist."
    exit 1
fi

# Start RStudio Server as the configured user
echo "Starting RStudio Server as user '$configured_user'..."
sudo -u "$configured_user" /usr/lib/rstudio-server/bin/rserver
