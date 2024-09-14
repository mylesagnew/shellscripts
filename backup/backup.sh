#!/usr/bin/env bash

# Load environment variables from .env file
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
else
    echo "Error: .env file not found!"
    exit 1
fi

[[ $EUID -ne 0 ]] && echo "Error: This script must be run as root!" && exit 1

# Default configurations loaded from .env or fallback values
ENCRYPTFLG=${ENCRYPTFLG:-true}
LOCALDIR=${LOCALDIR:-"/opt/backups/"}
TEMPDIR=${TEMPDIR:-"/opt/backups/temp/"}
LOGFILE=${LOGFILE:-"/opt/backups/backup.log"}
MYSQL_BACKUP_FLG=${MYSQL_BACKUP_FLG:-false}  # Flag to enable/disable MySQL backup
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD:-""}
MYSQL_DATABASE_NAME=(${MYSQL_DATABASE_NAME:-""})
BACKUP=(${BACKUP:-""})
LOCALAGEDAILIES=${LOCALAGEDAILIES:-7}
RCLONE_FLG=${RCLONE_FLG:-false}  # Flag to enable/disable Google Drive upload via rclone
FTP_FLG=${FTP_FLG:-false}        # Flag to enable/disable FTP upload
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

log() {
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $1" | tee -a "${LOGFILE}"
}

# Ensure required commands are available
check_commands() {
    REQUIRED_CMDS=(cat cd du date dirname echo openssl tar)
    if [[ "$MYSQL_BACKUP_FLG" == true && -n "$MYSQL_ROOT_PASSWORD" ]]; then
        REQUIRED_CMDS+=(mysql mysqldump)
    fi
    for cmd in "${REQUIRED_CMDS[@]}"; do
        command -v "$cmd" >/dev/null 2>&1 || { log "$cmd is required but not installed."; exit 1; }
    done
    [[ $RCLONE_FLG == true ]] && command -v rclone >/dev/null || { log "rclone not found, skipping upload"; return; }
    [[ $FTP_FLG == true ]] && command -v ftp >/dev/null || { log "ftp not found, skipping upload"; return; }
}

# Backup MySQL databases if enabled
mysql_backup() {
    if [[ "$MYSQL_BACKUP_FLG" == false ]]; then
        log "MySQL backup is disabled."
        return
    fi

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        log "Skipping MySQL backup, no password set."
        return
    fi

    for db in "${MYSQL_DATABASE_NAME[@]}"; do
        DBFILE="${TEMPDIR}${db}_${BACKUPDATE}.sql"
        mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" "$db" > "$DBFILE" && BACKUP+=("$DBFILE")
        log "MySQL backup for $db completed."
    done
}

# Start the backup process
start_backup() {
    [ -z "$BACKUP" ] && { log "No files to backup."; exit 1; }

    log "Creating tar archive"
    tar -czf "$TARFILE" "${BACKUP[@]}" || { log "Tar archive creation failed"; exit 1; }

    if [ "$ENCRYPTFLG" == true ]; then
        log "Encrypting backup"
        openssl enc -aes256 -in "$TARFILE" -out "$ENC_TARFILE" -pass pass:"$BACKUPPASS" -md sha1
        rm -f "$TARFILE"
        OUT_FILE="$ENC_TARFILE"
    else
        OUT_FILE="$TARFILE"
    fi
}

# Upload to Google Drive via rclone if enabled
rclone_upload() {
    [[ "$RCLONE_FLG" == false ]] && return
    command -v rclone >/dev/null || { log "rclone not found, skipping upload"; return; }
    [[ -z "$RCLONE_NAME" ]] && { log "RCLONE_NAME is not set, skipping upload"; return; }

    log "Uploading to Google Drive via rclone"
    rclone copy "$OUT_FILE" "${RCLONE_NAME}:${RCLONE_FOLDER}" || { log "rclone upload failed"; return; }
}

# Upload to FTP server if enabled
ftp_upload() {
    [[ "$FTP_FLG" == false ]] && return
    [[ -z "$FTP_HOST" || -z "$FTP_USER" || -z "$FTP_PASS" || -z "$FTP_DIR" ]] && { log "FTP details incomplete, skipping upload"; return; }

    log "Uploading to FTP"
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
    find "$LOCALDIR" -type f -mtime +"$LOCALAGEDAILIES" -name '*.tgz' -o -name '*.enc' -exec rm -f {} \;
    log "Old backups cleaned up."
}

# Main script execution
STARTTIME=$(date +%s)

# Create backup directories if they don't exist
[ ! -d "$LOCALDIR" ] && mkdir -p "$LOCALDIR"
[ ! -d "$TEMPDIR" ] && mkdir -p "$TEMPDIR"

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

ENDTIME=$(date +%s)
log "Backup and transfer completed in $((ENDTIME - STARTTIME)) seconds"
