#!/bin/bash

# backup_ollama_volumes.sh
# This script backs up Docker Compose volumes for the 'ollama' service into a tar archive.
# Usage: ./backup_ollama_volumes.sh [backup_directory]
# If backup_directory is not provided, defaults to 'models/' relative to the script's location.

set -e  # Exit immediately if a command exits with a non-zero status.

# Function to display usage information
usage() {
  echo "Usage: $0 [backup_directory]"
  echo "  backup_directory: Optional. Directory where the backup will be stored. Defaults to 'models/' relative to the script."
  exit 1
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set backup directory to the first argument or default to 'models/'
BACKUP_DIR="${1:-"$SCRIPT_DIR/models"}"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

echo "Starting backup of 'ollama' volumes..."

# Get container ID for the 'ollama' service using 'docker compose'
container_id=$(docker compose ps -q ollama)

if [ -z "$container_id" ]; then
  echo "Error: Container for service 'ollama' not found. Is the service running?"
  exit 1
fi

# Retrieve mount information (Source: host path, Destination: container path)
mounts=$(docker inspect -f '{{range .Mounts}}{{.Source}}:{{.Destination}} {{end}}' "$container_id")

if [ -z "$mounts" ]; then
  echo "Error: No volumes found for container 'ollama'."
  exit 1
fi

echo "Found the following mounts:"
echo "$mounts"

# Collect all host paths from mounts
host_paths=()
for mount in $mounts; do
  # Handle cases where mount points may contain colons by limiting to first colon
  src=$(echo "$mount" | cut -d':' -f1)
  host_paths+=("$src")
done

# Define backup file name with timestamp
timestamp=$(date +%Y%m%d_%H%M%S)
backup_file="$BACKUP_DIR/ollama_volumes_backup_$timestamp.tar"

# Create the tar archive using sudo to access all host paths
echo "Creating tar archive at '$backup_file'..."
sudo tar -cf "$backup_file" "${host_paths[@]}"

# Change ownership of the backup file to the normal user
echo "Setting ownership of the backup file to '$USER'..."
sudo chown "$USER":"$USER" "$backup_file"

echo "Backup successfully created at: $backup_file"
