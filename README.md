# Shell scripts

Two small Bash utilities for Linux servers and cloud shells:

- **[`backup/`](backup/)**: an encrypted file and MySQL backup with local retention, plus optional upload to Google Drive (rclone) or FTP.
- **[`cloudshell/`](cloudshell/)**: a menu that clones a repo of your Terraform and Ansible code and runs it from AWS CloudShell, Azure Cloud Shell or Google Cloud Shell.

These are personal utility scripts, not maintained products. Read them before running them.

## `backup/backup.sh`

Builds `<hostname>_<timestamp>.tgz` from the paths in `BACKUP_ITEMS`, plus optional `mysqldump` output. It then encrypts the archive with OpenSSL (AES-256, PBKDF2, 100,000 iterations), deletes local archives older than `LOCALAGEDAILIES` days, and optionally uploads the result.

```bash
cd backup
cp .env.example .env      # then edit .env and chmod 600 it
sudo ./backup.sh          # must run as root, from this directory
```

Key settings in `.env`:

| Variable | Purpose |
|---|---|
| `BACKUP_ITEMS` | Space-separated files and directories to archive |
| `LOCALDIR`, `TEMPDIR`, `LOGFILE` | Where archives, temporary dumps and the log go (default `/opt/backups/`) |
| `ENCRYPTFLG`, `BACKUPPASS` | Encrypt the archive, and the passphrase to use |
| `MYSQL_BACKUP_FLG`, `MYSQL_ROOT_PASSWORD`, `MYSQL_BACKUP_ALL`, `MYSQL_DATABASE_NAME` | MySQL dump options |
| `LOCALAGEDAILIES` | Days of local archives to keep |
| `RCLONE_FLG`, `RCLONE_NAME`, `RCLONE_FOLDER` | Upload to an rclone remote |
| `FTP_FLG`, `FTP_HOST`, `FTP_USER`, `FTP_PASS`, `FTP_DIR` | Upload over FTP |

Decrypt a backup with:

```bash
openssl enc -d -aes256 -pbkdf2 -iter 100000 -md sha256 -in host_20240101000000.tgz.enc -out restore.tgz
```

Example cron entry (daily at 02:30):

```cron
30 2 * * * cd /opt/shellscripts/backup && ./backup.sh >/dev/null 2>&1
```

### Security notes

- `BACKUPPASS` and `MYSQL_ROOT_PASSWORD` are passed on the command line (`-pass pass:` and `-p`), so other local users can see them in `ps` while the backup runs. On shared hosts, use a MySQL option file (`~/.my.cnf`, mode 600) and `-pass file:` instead.
- FTP sends credentials and data unencrypted. Prefer rclone, or SFTP if you adapt the script.
- `.env` is gitignored. Keep it `chmod 600` and owned by root.

## `cloudshell/`

`cs-deploy.sh` shows a menu and runs `aws_deploy.sh`, `az_deploy.sh` or `gcp_deploy.sh`. Each of these:

1. installs Terraform and Ansible if they are missing,
2. clones `REPO_URL` (edit the variables at the top of the script first),
3. runs `terraform init` and **`terraform apply -auto-approve`** in `terraform/`,
4. runs `ansible-playbook -i inventory main.yml` in `ansible/`.

```bash
cd cloudshell
./cs-deploy.sh
```

> [!WARNING]
> `terraform apply -auto-approve` applies changes with no plan review. Run `terraform plan` yourself first, or remove `-auto-approve`.

## Known issues

- AWS CloudShell runs Amazon Linux, but `aws_deploy.sh` installs Terraform with `apt`. Install Terraform with `yum`/`dnf` there instead.
- `az_deploy.sh` installs the Azure CLI with `curl … | sudo bash` (Azure Cloud Shell already has it).
- In `backup.sh`, `find … -exec log` cannot call the shell `log` function, so deleted old archives are not written to the log. The files are still removed.

## Licence

MIT. See [LICENSE](LICENSE).
