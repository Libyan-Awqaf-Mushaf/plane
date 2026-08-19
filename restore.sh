#!/bin/bash

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

POSTGRES_USER=${POSTGRES_USER:-plane}
POSTGRES_DB=${POSTGRES_DB:-plane}

# Check input arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: ./restore.sh <path_to_db_backup.sql.gz> <path_to_uploads_backup.tar.gz>"
    exit 1
fi

DB_BACKUP_PATH=$1
UPLOADS_BACKUP_PATH=$2

# Find container and volume
DB_CONTAINER=$(docker ps --filter "name=plane-db" --format "{{.Names}}" | head -n 1)
UPLOADS_VOLUME=$(docker volume ls --format "{{.Name}}" | grep "uploads" | head -n 1)

if [ -z "$DB_CONTAINER" ]; then
    echo "Error: plane-db container is not running."
    exit 1
fi

if [ -z "$UPLOADS_VOLUME" ]; then
    echo "Error: uploads volume not found."
    exit 1
fi

echo "Restoring database..."
gunzip -c "$DB_BACKUP_PATH" | docker exec -i "$DB_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"

if [ $? -eq 0 ]; then
    echo "✓ Database restored successfully!"
else
    echo "✗ Database restore failed."
fi

echo "Restoring uploads..."
# Run a temporary container to extract the backup into the volume
docker run --rm \
  -v "$UPLOADS_VOLUME":/volume \
  -v "$(pwd)/$(dirname "$UPLOADS_BACKUP_PATH")":/backup \
  alpine sh -c "rm -rf /volume/* && tar -xzf /backup/$(basename "$UPLOADS_BACKUP_PATH") -C /volume"

if [ $? -eq 0 ]; then
    echo "✓ Uploads restored successfully!"
else
    echo "✗ Uploads restore failed."
fi

echo "Restore completed!"
