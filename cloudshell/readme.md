CloudShell Deployment Script
This Bash script provides a unified interface for running CloudShell environments on AWS, Azure, and GCP. It allows users to easily deploy infrastructure using Terraform and configuration management using Ansible in cloud environments. The script includes an ASCII menu interface to select which CloudShell to run and automates deployment processes on each platform.

Features
Supports AWS, Azure, and Google Cloud Platform (GCP).
Terraform integration for infrastructure provisioning.
Ansible integration for configuration management.
ASCII-based menu interface for easy navigation.
Cross-platform execution using CloudShell services in all three major cloud providers.
Automates the setup of Terraform and Ansible within CloudShell environments for streamlined deployment.
Prerequisites
To use this script, you'll need the following:

Active accounts on AWS, Azure, and GCP.
Properly configured CloudShell environments on each platform.
Installed Terraform and Ansible (automated through the script if not present).
Access to GitHub where your Terraform and Ansible configurations are stored.
AWS
AWS account with CloudShell enabled.
Appropriate IAM permissions for deploying resources using Terraform and Ansible.
Azure
Azure account with access to Azure CloudShell.
Permissions for deploying resources and running configurations.
GCP
Google Cloud account with CloudShell enabled.
Required permissions for resource management and configuration.
