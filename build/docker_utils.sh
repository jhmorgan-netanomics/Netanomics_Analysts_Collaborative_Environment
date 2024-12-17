#!/bin/bash

# Set environment variables for EC2 IP and container name
export EC2_IP=52.70.230.30
export CONTAINER_NAME=collaborative-env

# Function to copy files from the EC2 host to the Docker container
ec2_to_docker() {
    if [ $# -ne 2 ]; then
        echo "Usage: ec2_to_docker <ec2_file> <container_path>"
        return 1
    fi
    docker cp "$1" "$CONTAINER_NAME":"$2"
}

# Function to copy files from the Docker container to the EC2 host
docker_to_ec2() {
    if [ $# -ne 2 ]; then
        echo "Usage: docker_to_ec2 <container_file> <ec2_path>"
        return 1
    fi
    docker cp "$CONTAINER_NAME":"$1" "$2"
}

# Function to execute a command inside the Docker container
docker_exec() {
    if [ $# -ne 1 ]; then
        echo "Usage: docker_exec <command>"
        return 1
    fi
    docker exec -it "$CONTAINER_NAME" $1
}
