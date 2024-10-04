#!/bin/bash

# Exit script on error
set -e

# Define variables
REPO_URL="https://github.com/your_username/your_repo.git"
TERRAFORM_DIR="terraform"   # Directory in your repo containing Terraform code
ANSIBLE_DIR="ansible"       # Directory in your repo containing Ansible playbooks
ANSIBLE_INVENTORY="inventory"  # Path to your ansible inventory file inside the ansible directory

# Ensure Git, Terraform, and Ansible are installed
echo "Checking for required tools..."

# Install Terraform if not installed
if ! command -v terraform &> /dev/null
then
    echo "Terraform is not installed. Installing Terraform..."
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo tee /etc/apt/trusted.gpg.d/hashicorp.asc
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install terraform
else
    echo "Terraform is already installed"
fi

# Install Ansible if not installed
if ! command -v ansible &> /dev/null
then
    echo "Ansible is not installed. Installing Ansible..."
    sudo apt-get update
    sudo apt-get install -y ansible
else
    echo "Ansible is already installed"
fi

# Clone the GitHub repository
echo "Cloning the repository from GitHub..."
if [ -d "your_repo" ]; then
  echo "Repo already exists. Pulling latest changes..."
  cd your_repo && git pull
else
  git clone "$REPO_URL"
  cd your_repo
fi

# Terraform Deployment
echo "Initializing and applying Terraform..."

# Change to the Terraform directory and apply the infrastructure
cd $TERRAFORM_DIR
terraform init
terraform apply -auto-approve

# Ansible Deployment
echo "Running Ansible playbooks..."

# Change to the Ansible directory and run the playbook(s)
cd ../$ANSIBLE_DIR
ansible-playbook -i $ANSIBLE_INVENTORY main.yml

echo "Deployment complete!"
