#!/bin/bash

# Debug: Print the input parameters
echo "DEBUG: Provided username: $1"

# Check if a username is provided
if [[ -z "$1" ]]; then
    echo "Error: No username provided."
    echo "Usage: update_rstudio.sh <username>"
    exit 1
fi

# Assign the provided username
username="$1"

# Ensure the user exists
if ! id -u "$username" &>/dev/null; then
    echo "Error: User '$username' does not exist. Please create the user first."
    exit 1
fi

# Rewrite rserver.conf to ensure correctness
echo "Rewriting RStudio Server configuration for user '$username'..."
cat <<EOF > /etc/rstudio/rserver.conf
rsession-which-r=/usr/local/bin/R
auth-none=1
www-frame-origin=same
server-user=$username
EOF

# Verify the contents of rserver.conf
echo "Contents of /etc/rstudio/rserver.conf after update:"
cat /etc/rstudio/rserver.conf

# Ensure necessary directories exist
echo "Ensuring necessary directories for RStudio Server..."
mkdir -p /var/log/rstudio-server
mkdir -p /var/lib/rstudio-server
mkdir -p /var/run/rstudio-server

# Adjust ownership of RStudio directories for the specified user
echo "Adjusting ownership of RStudio directories for user '$username'..."
chown -R "$username":"$username" /var/log/rstudio-server
chown -R "$username":"$username" /var/lib/rstudio-server
chown -R "$username":"$username" /var/run/rstudio-server

# Reapply permissions for `/var/run` directories
chmod 770 /var/run/rstudio-server
chmod 770 /var/run/rstudio-server/rstudio-rsession || true

echo "RStudio Server configuration updated successfully for user '$username'."
