#!/bin/bash

# Function to handle errors
handleError() {
    echo "Error: $1"
    exit 1
}

# Function to install necessary dependencies
installDependencies() {
    echo "Installing necessary dependencies..."
    apt update || handleError "Failed to update package lists"
    apt install -y nginx jq curl ufw || handleError "Failed to install dependencies"
    snap install --classic certbot || handleError "Failed to install Certbot"
}

# Function to configure UFW
configureUFW() {
    echo "Configuring UFW..."
    ufw allow OpenSSH comment "Allow OpenSSH" || handleError "Failed to allow OpenSSH through UFW"
    ufw allow 'Nginx Full' comment "Allow Nginx" || handleError "Failed to allow Nginx through UFW"
    ufw enable || handleError "Failed to enable UFW"
}

# Main function
main() {
    installDependencies
    configureUFW
    echo "Setup completed successfully."
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
else
    main
    exit 0
fi

