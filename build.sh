#!/bin/bash
# build.sh - builds the Docker image from the Dockerfile in this folder
# Usage: ./build.sh <image-name> [tag]
# Example: ./build.sh kannansudalai/dev v1

# Stop the script immediately if any command fails
# (so Jenkins marks the build as failed instead of continuing)
set -e

# $1 = first argument (image name). If not given, default to kannansudalai/dev
# ${1:-default} is bash syntax for "use $1, or the default if empty"
IMAGE=${1:-kannansudalai/dev}

# $2 = second argument (tag). If not given, default to "latest"
TAG=${2:-latest}

# Print a message so the Jenkins console log shows what is happening
echo "Building $IMAGE:$TAG ..."

# Build the image from the Dockerfile in the current folder (the "." at the end)
# -t gives the image its name and tag
docker build -t $IMAGE:$TAG .

# Reached only if the build succeeded (because of set -e)
echo "Build complete"