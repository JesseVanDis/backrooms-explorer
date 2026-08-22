#!/usr/bin/env bash

# Change to the directory where this script is located
cd "$(dirname "$0")" || exit 1

# Check if Docker is installed
if ! command -v docker >/dev/null 2>&1; then
    echo "Error: Docker is not installed or could not be found in PATH." >&2
    exit 1
fi

# Build the docker image if it doesn't exist locally
#if [[ "$(docker images -q backrooms-explorer-gimp 2> /dev/null)" == "" ]]; then
    echo "Building Docker image backrooms-explorer-gimp..."
    docker build -t backrooms-explorer-gimp tools/parse_xcf
#fi

# Create resources directory if it doesn't exist
mkdir -p "./resources"

# Run the parser in the Docker container
# We mount the assets and resources directories to the container
echo "Running docker"
docker run --rm \
    -v "$(pwd)/assets:/app/assets" \
    -v "$(pwd)/resources:/app/resources" \
    backrooms-explorer-gimp
