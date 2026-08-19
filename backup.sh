#!/bin/bash

# Setup directories
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Load environment variables
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found."
    exit 1
fi

POSTGRES_USER=${POSTGRES_USER:-plane}
POSTGRES_DB=${POSTGRES_DB:-plane}

# Find container names
DB_CONTAINER=$(docker ps --filter "name=plane-db" --format "{{.Names}}" | head -n 1)

if [ -z "$DB_CONTAINER" ]; then
    echo "Error: plane-db container is not running."
    exit 1
fi

echo "Starting database backup..."
DB_BACKUP_FILE="$BACKUP_DIR/plane_db_backup_$TIMESTAMP.sql"
docker exec -t "$DB_CONTAINER" pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" > "$DB_BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "✓ Database backup saved to $DB_BACKUP_FILE"
    # Compress the SQL file
    gzip "$DB_BACKUP_FILE"
    echo "✓ Compressed database backup: ${DB_BACKUP_FILE}.gz"
else
    echo "✗ Database backup failed."
fi

# Find uploads volume
UPLOADS_VOLUME=$(docker volume ls --format "{{.Name}}" | grep "uploads" | head -n 1)

if [ -n "$UPLOADS_VOLUME" ]; then
    echo "Starting uploads backup..."
    UPLOADS_BACKUP_FILE="$BACKUP_DIR/plane_uploads_backup_$TIMESTAMP.tar.gz"
    
    # Run a temporary alpine container to compress the volume content
    docker run --rm \
      -v "$UPLOADS_VOLUME":/volume \
      -v "$(pwd)/$BACKUP_DIR":/backup \
      alpine tar -czf "/backup/plane_uploads_backup_$TIMESTAMP.tar.gz" -C /volume .
      
    if [ $? -eq 0 ]; then
        echo "✓ Uploads backup saved to $UPLOADS_BACKUP_FILE"
    else
        echo "✗ Uploads backup failed."
    fi
else
    echo "Warning: uploads volume not found. Skipping file backup."
fi

echo "Backup completed successfully!"
