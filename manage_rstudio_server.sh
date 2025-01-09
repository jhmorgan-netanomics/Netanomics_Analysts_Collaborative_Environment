#!/bin/bash

# Usage: ./manage_rstudio.sh [container_name] [elastic_ip]
DEFAULT_CONTAINER_NAME="BEND"
DEFAULT_ELASTIC_IP="52.70.230.30"

CONTAINER_NAME=${1:-$DEFAULT_CONTAINER_NAME}
ELASTIC_IP=${2:-$DEFAULT_ELASTIC_IP}

echo "Managing RStudio Server for container: $CONTAINER_NAME"
echo "Using IP address: $ELASTIC_IP"

# Check if the container exists (running or stopped)
EXISTING_CONTAINER=$(docker ps -a --filter "name=$CONTAINER_NAME" --quiet)

if [ -n "$EXISTING_CONTAINER" ]; then
    RUNNING_CONTAINER=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)
    
    if [ -n "$RUNNING_CONTAINER" ]; then
        echo "Container '$CONTAINER_NAME' is already running. Attaching..."
        docker exec -it "$CONTAINER_NAME" /usr/local/bin/start_rstudio_server.sh
    else
        echo "Starting existing container '$CONTAINER_NAME'..."
        docker start "$CONTAINER_NAME"
        docker exec -it "$CONTAINER_NAME" /usr/local/bin/start_rstudio_server.sh
    fi
else
    echo "Creating and starting a new container: $CONTAINER_NAME"
    docker run -itd \
        -p 8787:8787 \
        -v /path/to/R/packages:/home/rstudio/R \
        -v /path/to/Julia/packages:/home/rstudio/.julia \
        -v /path/to/Python/packages:/home/rstudio/.local/lib/python3.8/site-packages \
        --name "$CONTAINER_NAME" collaborative-env
    docker exec -it "$CONTAINER_NAME" /usr/local/bin/start_rstudio_server.sh
fi

# Provide user instructions
echo "RStudio Server is now running."
echo "Access it at: http://$ELASTIC_IP:8787"
