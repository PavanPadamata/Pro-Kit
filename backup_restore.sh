#!/bin/bash

# Backup and Restore script for Docker Compose services with Logging

BACKUP_DIR="./backup"
LOG_DIR="./logs"
TIMESTAMP=$(date +"%Y%m%d%H%M")
BACKUP_PATH="$BACKUP_DIR/$TIMESTAMP"
LOG_FILE="$LOG_DIR/backup_restore_$TIMESTAMP.log"

# Create necessary directories
mkdir -p "$BACKUP_PATH"
mkdir -p "$LOG_DIR"

# Logging function
log_message() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Functions for Backup
backup_nginx() {
    log_message "Backing up Nginx Proxy Manager data..."
    docker run --rm --volumes-from $(docker-compose ps -q proxy) -v $BACKUP_PATH:/backup ubuntu tar czf /backup/nginx_data.tar.gz /data /etc/letsencrypt
    log_message "Nginx Proxy Manager backup completed."
}

backup_nextcloud() {
    log_message "Backing up Nextcloud app data..."
    docker run --rm --volumes-from $(docker-compose ps -q nextcloud_app) -v $BACKUP_PATH:/backup ubuntu tar czf /backup/nextcloud_data.tar.gz /var/www/html
    log_message "Nextcloud app data backup completed."

    log_message "Backing up Nextcloud database (MariaDB)..."
    docker exec $(docker-compose ps -q nextcloud_db) sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PASSWORD"' > "$BACKUP_PATH/nextcloud_db_backup.sql"
    log_message "Nextcloud database backup completed."
}

backup_onlyoffice() {
    log_message "Backing up OnlyOffice data..."
    docker run --rm --volumes-from $(docker-compose ps -q onlyoffice) -v $BACKUP_PATH:/backup ubuntu tar czf /backup/onlyoffice_data.tar.gz /var/www/onlyoffice
    log_message "OnlyOffice data backup completed."

    log_message "Backing up OnlyOffice database (PostgreSQL)..."
    docker exec $(docker-compose ps -q onlyoffice_db) pg_dumpall -U onlyoffice > "$BACKUP_PATH/onlyoffice_db_backup.sql"
    log_message "OnlyOffice database backup completed."
}

backup_synapse() {
    log_message "Backing up Synapse app data..."
    docker run --rm --volumes-from $(docker-compose ps -q synapse) -v $BACKUP_PATH:/backup ubuntu tar czf /backup/synapse_data.tar.gz /data
    log_message "Synapse app data backup completed."

    log_message "Backing up Synapse database (PostgreSQL)..."
    docker exec $(docker-compose ps -q synapse_db) pg_dumpall -U synapse_user > "$BACKUP_PATH/synapse_db_backup.sql"
    log_message "Synapse database backup completed."
}

backup_all() {
    log_message "Starting full backup of all services."
    backup_nginx
    backup_nextcloud
    backup_onlyoffice
    backup_synapse
    log_message "Full backup completed."
}

# Functions for Restore
restore_nginx() {
    log_message "Restoring Nginx Proxy Manager data..."
    docker-compose down
    docker run --rm -v $BACKUP_PATH:/backup -v $(docker-compose ps -q proxy):/data -v $(docker-compose ps -q proxy):/etc/letsencrypt ubuntu tar xzf /backup/nginx_data.tar.gz -C /
    docker-compose up -d proxy
    log_message "Nginx Proxy Manager restore completed."
}

restore_nextcloud() {
    log_message "Restoring Nextcloud app data..."
    docker-compose down
    docker run --rm -v $BACKUP_PATH:/backup -v $(docker-compose ps -q nextcloud_app):/var/www/html ubuntu tar xzf /backup/nextcloud_data.tar.gz -C /
    docker-compose up -d nextcloud_app
    log_message "Nextcloud app data restore completed."

    log_message "Restoring Nextcloud database..."
    docker exec -i $(docker-compose ps -q nextcloud_db) mysql -uroot -p"$MYSQL_ROOT_PASSWORD" < "$BACKUP_PATH/nextcloud_db_backup.sql"
    log_message "Nextcloud database restore completed."
}

restore_onlyoffice() {
    log_message "Restoring OnlyOffice data..."
    docker-compose down
    docker run --rm -v $BACKUP_PATH:/backup -v $(docker-compose ps -q onlyoffice):/var/www/onlyoffice ubuntu tar xzf /backup/onlyoffice_data.tar.gz -C /
    docker-compose up -d onlyoffice
    log_message "OnlyOffice app data restore completed."

    log_message "Restoring OnlyOffice database..."
    docker exec -i $(docker-compose ps -q onlyoffice_db) psql -U onlyoffice < "$BACKUP_PATH/onlyoffice_db_backup.sql"
    log_message "OnlyOffice database restore completed."
}

restore_synapse() {
    log_message "Restoring Synapse app data..."
    docker-compose down
    docker run --rm -v $BACKUP_PATH:/backup -v $(docker-compose ps -q synapse):/data ubuntu tar xzf /backup/synapse_data.tar.gz -C /
    docker-compose up -d synapse
    log_message "Synapse app data restore completed."

    log_message "Restoring Synapse database..."
    docker exec -i $(docker-compose ps -q synapse_db) psql -U synapse_user < "$BACKUP_PATH/synapse_db_backup.sql"
    log_message "Synapse database restore completed."
}

restore_all() {
    log_message "Starting full restore of all services."
    restore_nginx
    restore_nextcloud
    restore_onlyoffice
    restore_synapse
    log_message "Full restore completed."
}

# Menu for user input
echo "Select operation:"
echo "1. Backup All"
echo "2. Restore All"
echo "3. Backup Nginx Proxy Manager"
echo "4. Restore Nginx Proxy Manager"
echo "5. Backup Nextcloud"
echo "6. Restore Nextcloud"
echo "7. Backup OnlyOffice"
echo "8. Restore OnlyOffice"
echo "9. Backup Synapse"
echo "10. Restore Synapse"

read -p "Enter your choice: " choice

case $choice in
    1)
        backup_all
        ;;
    2)
        restore_all
        ;;
    3)
        backup_nginx
        ;;
    4)
        restore_nginx
        ;;
    5)
        backup_nextcloud
        ;;
    6)
        restore_nextcloud
        ;;
    7)
        backup_onlyoffice
        ;;
    8)
        restore_onlyoffice
        ;;
    9)
        backup_synapse
        ;;
    10)
        restore_synapse
        ;;
    *)
        log_message "Invalid choice!"
        echo "Invalid choice!"
        ;;
esac

# Automated daily backups via cron job (optional)
# Add this line to crontab (with crontab -e) to run the script daily at midnight
# 0 0 * * * /path/to/your_script.sh > /dev/null 2>&1
