System Maintenance Scripts
Overview
This repository contains two essential shell scripts designed for automating system maintenance tasks on Linux servers:

Backup Script

Purpose: Automates the process of backing up important files, databases, and directories to a designated location.
Features:
Compresses backup data using tar/gzip.
Supports both local and remote backups (e.g., via SCP or Rsync).
Scheduled via cron for regular backups.
Linux Hardening Script

Purpose: Enhances the security of a Linux system by applying key hardening configurations.
Features:
Disables unused services and unnecessary network ports.
Enforces secure file permissions and password policies.
Configures firewall rules and logs suspicious activity.
Integrates automatic updates for critical security patches.
