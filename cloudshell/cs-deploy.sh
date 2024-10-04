#!/bin/bash

# Function to deploy using AWS deployment script
aws_deployment() {
    if [[ -f "./aws_deploy.sh" ]]; then
        echo "Running AWS deployment script..."
        bash ./aws_deploy.sh
    else
        echo "aws_deploy.sh script not found!"
    fi
}

# Function to deploy using Azure deployment script
azure_deployment() {
    if [[ -f "./az_deploy.sh" ]]; then
        echo "Running Azure deployment script..."
        bash ./az_deploy.sh
    else
        echo "az_deploy.sh script not found!"
    fi
}

# Function to deploy using GCP deployment script
gcp_deployment() {
    if [[ -f "./gcp_deploy.sh" ]]; then
        echo "Running GCP deployment script..."
        bash ./gcp_deploy.sh
    else
        echo "gcp_deploy.sh script not found!"
    fi
}

# Function to display menu
show_menu() {
    echo "============================"
    echo " Cloudshell Deployment Menu "
    echo "============================"
    echo "1. AWS Deployment (aws_deploy.sh)"
    echo "2. Azure Deployment (az_deploy.sh)"
    echo "3. GCP Deployment (gcp_deploy.sh)"
    echo "4. Exit"
    echo -n "Please choose an option [1-4]: "
}

# Main script loop
while true; do
    show_menu
    read -r choice
    case $choice in
        1)
            aws_deployment
            ;;
        2)
            azure_deployment
            ;;
        3)
            gcp_deployment
            ;;
        4)
            echo "Exiting..."
            break
            ;;
        *)
            echo "Invalid option, please select between 1 and 4."
            ;;
    esac
done
