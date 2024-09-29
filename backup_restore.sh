#!/bin/bash

# Variables
COMPOSE_FILE_PATH="./docker-compose.yml"  # Assuming the compose file is in the same directory
BACKUP_DIR="./backup"                      # Assuming the backup directory is in the same directory
DATE=$(date +"%Y%m%d_%H%M")

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Function to backup
backup() {
    echo "Starting backup..."

    # Backup Nextcloud data
    echo "Backing up Nextcloud data..."
    docker-compose -f "$COMPOSE_FILE_PATH" exec nextcloud bash -c "tar czf /mnt/nextcloud_backup_$DATE.tar.gz /var/www/html/data"
    docker cp $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q nextcloud):/mnt/nextcloud_backup_$DATE.tar.gz "$BACKUP_DIR/nextcloud_backup_$DATE.tar.gz"

    # Backup OnlyOffice data
    echo "Backing up OnlyOffice data..."
    docker-compose -f "$COMPOSE_FILE_PATH" exec onlyoffice bash -c "tar czf /mnt/onlyoffice_backup_$DATE.tar.gz /var/www/onlyoffice/data"
    docker cp $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q onlyoffice):/mnt/onlyoffice_backup_$DATE.tar.gz "$BACKUP_DIR/onlyoffice_backup_$DATE.tar.gz"

    # Backup databases
    echo "Backing up Nextcloud database..."
    docker-compose -f "$COMPOSE_FILE_PATH" exec nextcloud bash -c "mysqldump -u root -p\$MYSQL_ROOT_PASSWORD nextcloud > /mnt/nextcloud_db_backup_$DATE.sql"
    docker cp $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q nextcloud):/mnt/nextcloud_db_backup_$DATE.sql "$BACKUP_DIR/nextcloud_db_backup_$DATE.sql"

    echo "Backing up OnlyOffice database..."
    docker-compose -f "$COMPOSE_FILE_PATH" exec onlyoffice bash -c "mysqldump -u root -p\$MYSQL_ROOT_PASSWORD onlyoffice > /mnt/onlyoffice_db_backup_$DATE.sql"
    docker cp $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q onlyoffice):/mnt/onlyoffice_db_backup_$DATE.sql "$BACKUP_DIR/onlyoffice_db_backup_$DATE.sql"

    echo "Backup completed successfully!"
}

# Function to restore
restore() {
    if [ -z "$1" ]; then
        echo "Please provide the backup date in the format YYYYMMDD_HHMM."
        exit 1
    fi

    BACKUP_DATE="$1"

    echo "Starting restore from backup date: $BACKUP_DATE"

    # Restore Nextcloud data
    echo "Restoring Nextcloud data..."
    docker cp "$BACKUP_DIR/nextcloud_backup_$BACKUP_DATE.tar.gz" $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q nextcloud):/mnt/
    docker-compose -f "$COMPOSE_FILE_PATH" exec nextcloud bash -c "tar xzf /mnt/nextcloud_backup_$BACKUP_DATE.tar.gz -C /var/www/html/data"

    # Restore OnlyOffice data
    echo "Restoring OnlyOffice data..."
    docker cp "$BACKUP_DIR/onlyoffice_backup_$BACKUP_DATE.tar.gz" $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q onlyoffice):/mnt/
    docker-compose -f "$COMPOSE_FILE_PATH" exec onlyoffice bash -c "tar xzf /mnt/onlyoffice_backup_$BACKUP_DATE.tar.gz -C /var/www/onlyoffice/data"

    # Restore databases
    echo "Restoring Nextcloud database..."
    docker cp "$BACKUP_DIR/nextcloud_db_backup_$BACKUP_DATE.sql" $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q nextcloud):/mnt/
    docker-compose -f "$COMPOSE_FILE_PATH" exec nextcloud bash -c "mysql -u root -p\$MYSQL_ROOT_PASSWORD nextcloud < /mnt/nextcloud_db_backup_$BACKUP_DATE.sql"

    echo "Restoring OnlyOffice database..."
    docker cp "$BACKUP_DIR/onlyoffice_db_backup_$BACKUP_DATE.sql" $(docker-compose -f "$COMPOSE_FILE_PATH" ps -q onlyoffice):/mnt/
    docker-compose -f "$COMPOSE_FILE_PATH" exec onlyoffice bash -c "mysql -u root -p\$MYSQL_ROOT_PASSWORD onlyoffice < /mnt/onlyoffice_db_backup_$BACKUP_DATE.sql"

    echo "Restore completed successfully!"
}

# Main script
if [ "$1" == "backup" ]; then
    backup
elif [ "$1" == "restore" ]; then
    restore "$2"
else
    echo "Usage: $0 {backup|restore [backup_date]}"
    exit 1
fi
