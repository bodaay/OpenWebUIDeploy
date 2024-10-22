#!/bin/bash

# -----------------------------------------------------------------------------
# Script Name: download_docker_images.sh
# Description: Downloads specified Docker images and saves them as tar files
#              for offline transfer.
# Requirements:
#   - Docker must be installed and running.
# Usage:
#   chmod +x download_docker_images.sh
#   ./download_docker_images.sh
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status
set -e

# Define the Docker images to download
IMAGES=(
  "ghcr.io/open-webui/open-webui:main"
  "ghcr.io/open-webui/open-webui:cuda"
  "postgres:latest"  # It's good practice to specify the tag; 'latest' is default if omitted
  "ollama/ollama:latest"
  "nginx:latest"
)

# Directory where tar files will be saved
OUTPUT_DIR="docker_images_tar"

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

echo "Starting the Docker image download and save process..."

# Loop through each image
for IMAGE in "${IMAGES[@]}"; do
  echo "----------------------------------------"
  echo "Processing image: $IMAGE"

  # Pull the latest version of the image
  echo "Pulling image..."
  if docker pull "$IMAGE"; then
    echo "Successfully pulled $IMAGE"
  else
    echo "Error: Failed to pull $IMAGE. Skipping to next image."
    continue
  fi

  # Sanitize image name for filename (replace '/' and ':' with '_')
  FILE_NAME=$(echo "$IMAGE" | tr '/:' '__').tar

  # Full path for the tar file
  TAR_PATH="$OUTPUT_DIR/$FILE_NAME"

  # Save the image as a tar file
  echo "Saving image to $TAR_PATH..."
  if docker save -o "$TAR_PATH" "$IMAGE"; then
    echo "Successfully saved $IMAGE to $TAR_PATH"
  else
    echo "Error: Failed to save $IMAGE. Skipping to next image."
    continue
  fi
done

echo "----------------------------------------"
echo "All specified Docker images have been processed."
echo "Tar files are located in the '$OUTPUT_DIR' directory."

# Optional: Compress the tar files to save space
# Uncomment the lines below if you wish to compress the tar files using gzip

# echo "Compressing tar files to save space..."
# for TAR_FILE in "$OUTPUT_DIR"/*.tar; do
#   gzip "$TAR_FILE"
#   echo "Compressed $TAR_FILE to $TAR_FILE.gz"
# done
# echo "Compression completed."

echo "Script execution finished."

