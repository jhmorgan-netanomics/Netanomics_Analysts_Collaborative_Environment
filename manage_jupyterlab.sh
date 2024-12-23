if [ "$COMMAND" == "initialize" ]; then
    echo "Using provided Elastic IP: $ELASTIC_IP"

    # Stop any running container with the same name
    EXISTING_CONTAINER=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)
    if [ -n "$EXISTING_CONTAINER" ]; then
        echo "Stopping and removing the container: $EXISTING_CONTAINER"
        docker stop "$EXISTING_CONTAINER"
        docker rm "$EXISTING_CONTAINER"
    fi

    # Check for processes using port 8888 and kill them if necessary
    PORT_PID=$(lsof -ti:8888)
    if [ -n "$PORT_PID" ]; then
        echo "Killing process on port 8888: $PORT_PID"
        kill -9 "$PORT_PID"
    fi

    # Start the container with both ports exposed
    echo "Starting a new container named '$CONTAINER_NAME'..."
    docker run -itd -p 8888:8888 -p 8080:8080 --name "$CONTAINER_NAME" collaborative-env jupyter
    CONTAINER_ID=$(docker ps --filter "name=$CONTAINER_NAME" --quiet)

    echo "Activating Python virtual environment at $VENV_PATH..."
    source $VENV_PATH/bin/activate
    echo "Virtual environment activated. Using Python: $(which python)"

    # Retrieve the JupyterLab token
    echo "Fetching JupyterLab token..."
    sleep 5  # Allow time for JupyterLab to initialize
    TOKEN=$(docker logs "$CONTAINER_ID" 2>&1 | grep -oP "token=\K[^&]+")
    if [ -n "$TOKEN" ]; then
        echo "JupyterLab started. Access it at: http://$ELASTIC_IP:8888/lab?token=$TOKEN"
    else
        echo "Failed to retrieve JupyterLab token. Check the container logs for details."
    fi
