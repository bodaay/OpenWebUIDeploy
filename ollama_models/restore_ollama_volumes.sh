#!/bin/bash

# restore_ollama_volumes.sh
# This script restores Docker Compose volumes for the 'ollama' service from a tar archive.
# Usage: ./restore_ollama_volumes.sh [backup_file.tar]
# If backup_file.tar is not provided, defaults to the latest backup in 'models/' directory relative to the script.

set -e  # Exit immediately if a command exits with a non-zero status.

# Function to display usage information
usage() {
  echo "Usage: $0 [backup_file.tar]"
  echo "  backup_file.tar: Optional. Path to the backup archive. Defaults to the latest backup in 'models/' directory relative to the script."
  exit 1
}

# Check for help flag
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
  usage
fi

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set backup directory to 'models/' relative to the script's location
BACKUP_DIR="$SCRIPT_DIR/models"

# Set backup file to the first argument or find the latest tar in BACKUP_DIR
if [ -n "$1" ]; then
  BACKUP_FILE="$1"
else
  # Find the latest tar file in BACKUP_DIR matching the backup pattern
  BACKUP_FILE=$(ls -t "$BACKUP_DIR"/ollama_volumes_backup_*.tar 2>/dev/null | head -n1)

  if [ -z "$BACKUP_FILE" ]; then
    echo "Error: No backup file specified and no backups found in '$BACKUP_DIR'."
    exit 1
  fi
fi

# Validate backup file
if [ ! -f "$BACKUP_FILE" ]; then
  echo "Error: Backup file '$BACKUP_FILE' does not exist."
  exit 1
fi

echo "Starting restoration of 'ollama' volumes from '$BACKUP_FILE'..."

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

# Iterate over each mount and restore its contents
for mount in $mounts; do
  # Handle cases where mount points may contain colons by limiting to first colon
  src=$(echo "$mount" | cut -d':' -f1)
  dst=$(echo "$mount" | cut -d':' -f2-)

  # Remove leading '/' from destination to get relative path
  dst_rel=${dst#/}

  echo "Restoring volume: Host Path='$src' <- Container Path='$dst'"

  # Check if the backup contains data for this mount
  # List contents of tar to see if the path exists
  if sudo tar -tf "$BACKUP_FILE" | grep -q "^${src#/}"; then
    # Extract only the specific directory from the tar archive
    sudo tar -xf "$BACKUP_FILE" "$src"
    echo "Successfully restored volume at '$src'."
  else
    echo "Warning: No backup data found for mount '$dst'. Skipping."
  fi
done

echo "Restoration of 'ollama' volumes completed successfully."
