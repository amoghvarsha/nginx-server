#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Function to install necessary dependencies
install_dependencies() {
    echo "Installing necessary dependencies..."
    apt update || handle_error "Failed to update package lists"
    apt install -y nginx jq curl || handle_error "Failed to install dependencies"
    snap install --classic certbot || handle_error "Failed to install Certbot"
}

# Function to configure UFW
configure_ufw() {
    echo "Configuring UFW..."
    ufw allow OpenSSH comment "Allow OpenSSH" || handle_error "Failed to allow OpenSSH through UFW"
    ufw allow 'Nginx Full' comment "Allow Nginx" || handle_error "Failed to allow Nginx through UFW"
    ufw enable || handle_error "Failed to enable UFW"
}

# Main function
main() {
    install_dependencies
    configure_ufw
    echo "Setup completed successfully."
}

# Execute main function
main
