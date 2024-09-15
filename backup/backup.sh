#!/usr/bin/env bash

# Load environment variables from .env file
if [[ -f .env ]]; then
    source .env
else
    echo "Error: .env file not found!"
    exit 1
fi

# Check if script is running as root
[[ $EUID -ne 0 ]] && echo "Error: This script must be run as root!" && exit 1

# Default configurations loaded from .env or fallback values
ENCRYPTFLG=${ENCRYPTFLG:-true}
LOCALDIR=${LOCALDIR:-"/opt/backups/"}
TEMPDIR=${TEMPDIR:-"/opt/backups/temp/"}
LOGFILE=${LOGFILE:-"/opt/backups/backup.log"}
MYSQL_BACKUP_FLG=${MYSQL_BACKUP_FLG:-false}  # Enable/disable MySQL backup
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-""}
MYSQL_BACKUP_ALL=${MYSQL_BACKUP_ALL:-false}  # Backup all MySQL databases
MYSQL_DATABASE_NAME=(${MYSQL_DATABASE_NAME:-""})  # Specific databases to backup
BACKUP_ITEMS=(${BACKUP_ITEMS:-""})  # Files and folders to backup
LOCALAGEDAILIES=${LOCALAGEDAILIES:-7}
RCLONE_FLG=${RCLONE_FLG:-false}  # Enable/disable Google Drive upload via rclone
FTP_FLG=${FTP_FLG:-false}        # Enable/disable FTP upload
RCLONE_NAME=${RCLONE_NAME:-""}
RCLONE_FOLDER=${RCLONE_FOLDER:-""}
FTP_HOST=${FTP_HOST:-""}
FTP_USER=${FTP_USER:-""}
FTP_PASS=${FTP_PASS:-""}
FTP_DIR=${FTP_DIR:-""}
# Date & Time
BACKUPDATE=$(date +%Y%m%d%H%M%S)
TARFILE="${LOCALDIR}$(hostname)_${BACKUPDATE}.tgz"
ENC_TARFILE="${TARFILE}.enc"
SQLFILE="${TEMPDIR}mysql_${BACKUPDATE}.sql"

# Logging function
log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" | tee -a "${LOGFILE}"
}

# Check for required commands
check_commands() {
    local required_cmds=("cat" "cd" "du" "date" "dirname" "echo" "openssl" "tar")
    if [[ "$MYSQL_BACKUP_FLG" == true && -n "$MYSQL_ROOT_PASSWORD" ]]; then
        required_cmds+=("mysql" "mysqldump")
    fi

    for cmd in "${required_cmds[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || { log "$cmd is required but not installed."; exit 1; }
    done

    [[ "$RCLONE_FLG" == true ]] && command -v rclone >/dev/null || log "rclone not found, skipping upload"
    [[ "$FTP_FLG" == true ]] && command -v ftp >/dev/null || log "ftp not found, skipping upload"
}

# Backup MySQL databases if enabled
mysql_backup() {
    if [[ "$MYSQL_BACKUP_FLG" == false ]]; then
        log "MySQL backup is disabled."
        return
    fi

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        log "MySQL root password not set, skipping MySQL backup."
        return
    fi

    if [[ "$MYSQL_BACKUP_ALL" == true || -z "$MYSQL_DATABASE_NAME" ]]; then
        log "Backing up all MySQL databases"
        mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$SQLFILE"
        if [ $? -eq 0 ]; then
            log "MySQL backup completed."
            BACKUP_ITEMS+=("$SQLFILE")
        else
            log "MySQL backup failed."
            exit 1
        fi
    else
        for db in "${MYSQL_DATABASE_NAME[@]}"; do
            local DBFILE="${TEMPDIR}${db}_${BACKUPDATE}.sql"
            log "Backing up MySQL database: $db"
            mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" "$db" > "$DBFILE"
            if [ $? -eq 0 ]; then
                log "MySQL backup for $db completed."
                BACKUP_ITEMS+=("$DBFILE")
            else
                log "MySQL backup for $db failed."
            fi
        done
    fi
}

# Start the backup process
start_backup() {
    if [[ -z "${BACKUP_ITEMS[*]}" ]]; then
        log "No files to backup."
        exit 1
    fi

    log "Creating tar archive at $TARFILE"
    tar -czf "$TARFILE" "${BACKUP_ITEMS[@]}" || { log "Tar archive creation failed"; exit 1; }

    # Check if tar file exists
    if [[ -f "$TARFILE" ]]; then
        log "Tar archive created successfully: $TARFILE"
    else
        log "Error: Tar archive was not created at $TARFILE."
        exit 1
    fi

    if [ "$ENCRYPTFLG" == true ]; then
        if [[ -z "$BACKUPPASS" ]]; then
            log "Error: ENCRYPTFLG is set to true but no encryption password (BACKUPPASS) is provided."
            exit 1
        fi

        log "Encrypting the backup using AES256 with PBKDF2"
        openssl enc -aes256 -in "$TARFILE" -out "$ENC_TARFILE" -pass pass:"$BACKUPPASS" -pbkdf2 -iter 100000 -md sha256 2>>"${LOGFILE}"

        # Check if encryption was successful
        if [ $? -eq 0 ]; then
            log "Encryption successful, removing unencrypted tar file"
            rm -f "$TARFILE"
            OUT_FILE="$ENC_TARFILE"
        else
            log "Encryption failed, check OpenSSL error in the log file"
            OUT_FILE="$TARFILE"
        fi

        # Check if the encrypted file was created
        if [[ -f "$ENC_TARFILE" ]]; then
            log "Encrypted backup file created successfully: $ENC_TARFILE"
        else
            log "Error: Encrypted backup file was not created at $ENC_TARFILE."
            exit 1
        fi
    else
        log "Encryption is disabled, using unencrypted tar file"
        OUT_FILE="$TARFILE"
    fi
}

# Upload to Google Drive via rclone if enabled
rclone_upload() {
    [[ "$RCLONE_FLG" == false ]] && return
    [[ -z "$RCLONE_NAME" ]] && { log "RCLONE_NAME is not set, skipping upload"; return; }

    log "Uploading backup to Google Drive via rclone"
    rclone copy "$OUT_FILE" "${RCLONE_NAME}:${RCLONE_FOLDER}" || log "rclone upload failed"
}

# Upload to FTP server if enabled
ftp_upload() {
    [[ "$FTP_FLG" == false ]] && return
    [[ -z "$FTP_HOST" || -z "$FTP_USER" || -z "$FTP_PASS" || -z "$FTP_DIR" ]] && { log "FTP details incomplete, skipping upload"; return; }

    log "Uploading backup to FTP server"
    ftp -n "$FTP_HOST" <<EOF
user $FTP_USER $FTP_PASS
binary
lcd $LOCALDIR
cd $FTP_DIR
put $(basename "$OUT_FILE")
bye
EOF
}

# Cleanup old backups based on retention policy
clean_up_files() {
    log "Starting cleanup of old backups in $LOCALDIR"

    # Find and delete files older than $LOCALAGEDAILIES days
    find "$LOCALDIR" -type f \( -name '*.tgz' -o -name '*.enc' \) -mtime +"$LOCALAGEDAILIES" -exec rm -f {} \; -exec log "Deleted: {}" \;

    log "Cleanup of old backups completed."
}

# Clean up temporary files in the temp directory
clean_up_temp_files() {
    log "Cleaning up temporary files in $TEMPDIR"
    rm -rf "${TEMPDIR:?}"/* || log "Failed to clean up temporary files."
}

# Main script execution
STARTTIME=$(date +%s)

# Ensure backup directories exist
mkdir -p "$LOCALDIR" "$TEMPDIR"

log "Starting backup process"
check_commands
mysql_backup
start_backup
log "Backup completed"

log "Starting upload process"
rclone_upload
ftp_upload
log "Upload completed"

log "Cleaning up old backups"
clean_up_files

log "Cleaning up temporary files"
clean_up_temp_files

ENDTIME=$(date +%s)
log "Backup and transfer completed in $((ENDTIME - STARTTIME)) seconds"
