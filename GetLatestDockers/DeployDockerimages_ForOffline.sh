#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: install_docker_images.sh
# Description: Loads Docker images from tar files into the local Docker registry.
#              Before loading, it stops and removes any existing containers
#              using the same images and deletes the old images to avoid conflicts.
# Requirements:
#   - Docker must be installed and running.
#   - Tar files should be present in the specified directory.
# Usage:
#   chmod +x install_docker_images.sh
#   ./install_docker_images.sh [path_to_tar_files_directory]
#   If no directory is specified, defaults to 'docker_images_tar'.
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display usage information
usage() {
  echo "Usage: $0 [path_to_tar_files_directory]"
  echo "If no directory is specified, defaults to 'docker_images_tar'."
  exit 1
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

# Directory containing the tar files
OUTPUT_DIR="${1:-docker_images_tar}"

# Check if the directory exists
if [[ ! -d "$OUTPUT_DIR" ]]; then
  echo "Error: Directory '$OUTPUT_DIR' does not exist."
  echo "Please ensure the directory exists and contains the Docker image tar files."
  exit 1
fi

echo "Starting the Docker image installation process..."
echo "Looking for tar files in the directory: '$OUTPUT_DIR'"

# Find all .tar files in the specified directory
TAR_FILES=("$OUTPUT_DIR"/*.tar)

# Check if there are any tar files to process
if [[ ! -e "${TAR_FILES[0]}" ]]; then
  echo "No tar files found in '$OUTPUT_DIR'. Exiting."
  exit 0
fi

# Function to extract image name and tag from a tar file
get_image_name_from_tar() {
  local tar_file="$1"
  
  # Extract manifest.json and parse RepoTags
  # This method avoids using external tools like jq
  IMAGE_NAME=$(tar -xOf "$tar_file" manifest.json | grep '"RepoTags"' -A1 | grep '"' | sed 's/.*"\([^"]*\)".*/\1/')
  
  echo "$IMAGE_NAME"
}

# Function to stop and remove containers using a specific image
stop_and_remove_containers() {
  local image="$1"
  
  # Get container IDs using the image (both running and stopped)
  CONTAINERS=$(docker ps -a --filter "ancestor=$image" -q)
  
  if [[ -n "$CONTAINERS" ]]; then
    echo "Found containers using image '$image': $CONTAINERS"
    
    # Stop the containers if they are running
    RUNNING_CONTAINERS=$(docker ps --filter "ancestor=$image" -q)
    if [[ -n "$RUNNING_CONTAINERS" ]]; then
      echo "Stopping running containers: $RUNNING_CONTAINERS"
      docker stop $RUNNING_CONTAINERS
    fi
    
    # Remove the containers
    echo "Removing containers: $CONTAINERS"
    docker rm $CONTAINERS
  else
    echo "No containers are using the image '$image'."
  fi
}

# Function to remove an image
remove_image() {
  local image="$1"
  
  # Check if the image exists
  if docker image inspect "$image" > /dev/null 2>&1; then
    echo "Removing existing image '$image'..."
    docker rmi "$image"
    echo "Successfully removed image '$image'."
  else
    echo "Image '$image' does not exist locally. No need to remove."
  fi
}

# Loop through each tar file and process it
for TAR_FILE in "${TAR_FILES[@]}"; do
  # Check if it's a regular file
  if [[ ! -f "$TAR_FILE" ]]; then
    echo "Skipping '$TAR_FILE' as it is not a regular file."
    continue
  fi

  echo "----------------------------------------"
  echo "Processing tar file: $TAR_FILE"

  # Extract image name and tag from the tar file
  IMAGE_NAME=$(get_image_name_from_tar "$TAR_FILE")
  
  if [[ -z "$IMAGE_NAME" || "$IMAGE_NAME" == "null" ]]; then
    echo "Error: Could not determine image name from '$TAR_FILE'. Skipping."
    continue
  fi
  
  echo "Image to be loaded: $IMAGE_NAME"

  # Check if the image already exists
  if docker image inspect "$IMAGE_NAME" > /dev/null 2>&1; then
    echo "Image '$IMAGE_NAME' already exists. Preparing to remove it."
    
    # Stop and remove any containers using this image
    stop_and_remove_containers "$IMAGE_NAME"
    
    # Remove the existing image
    remove_image "$IMAGE_NAME"
  else
    echo "Image '$IMAGE_NAME' does not exist locally. No need to remove."
  fi

  # Load the Docker image from the tar file
  echo "Loading image from '$TAR_FILE'..."
  LOAD_OUTPUT=$(docker load -i "$TAR_FILE")
  
  echo "$LOAD_OUTPUT"

  # Verify that the image was loaded successfully
  if echo "$LOAD_OUTPUT" | grep -q "Loaded image:"; then
    echo "Successfully loaded image '$IMAGE_NAME' from '$TAR_FILE'."
  else
    echo "Error: Failed to load image from '$TAR_FILE'."
    continue
  fi
done

echo "----------------------------------------"
echo "All Docker images have been processed."
echo "You can verify the loaded images using 'docker images'."

# Optional: Verify loaded images
echo "Verifying loaded Docker images..."
docker images

echo "Script execution finished."
