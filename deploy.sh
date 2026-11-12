#!/bin/bash
# deploy.sh - runs on the SERVER: pulls the image and starts the container
# Usage: ./deploy.sh <image-name> [tag]
# Example: ./deploy.sh kannansudalai/prod latest

# Stop the script immediately if any command fails
set -e

# Image name and tag, with the same defaults as build.sh
IMAGE=${1:-kannansudalai/dev}
TAG=${2:-latest}

# Fixed container name, so we can find and replace it on every deploy
CONTAINER=react-app

# Download the newest version of the image from Docker Hub
# (for a private repo, run "docker login" on the server once first)
docker pull $IMAGE:$TAG

# Remove the old container if it exists (-f also stops it if running)
# 2>/dev/null hides the "no such container" error on the first deploy
# || true stops set -e from failing the script in that case
docker rm -f $CONTAINER 2>/dev/null || true

# Start the new container:
#   -d                  run in the background
#   --name              the fixed name from above
#   -p 80:80            server port 80 -> container port 80
#   --restart always    start again automatically after a reboot or crash
docker run -d --name $CONTAINER -p 80:80 --restart always $IMAGE:$TAG

# Show the running container as a quick confirmation in the log
docker ps --filter name=$CONTAINER