#!/bin/bash

echo "Starting RStudio Server in the container..."

# Ensure the script runs as the 'netanomics' user
if [ "$(whoami)" != "netanomics" ]; then
    echo "Switching to user 'netanomics'..."
    exec su - netanomics -c "/usr/local/bin/start_rstudio_server.sh"
    exit
fi

# Start RStudio Server
echo "Running RStudio Server as 'netanomics'..."
/usr/lib/rstudio-server/bin/rserver --server-user netanomics &

# Wait for the server to start
sleep 2

# Check if the server is running
if pgrep -x "rserver" > /dev/null; then
    echo "RStudio Server started successfully."
else
    echo "Failed to start RStudio Server. Check logs for details."
    exit 1
fi

# Prevent the container from exiting
echo "Tailing RStudio Server logs..."
tail -f /var/log/rstudio-server/rserver.log
