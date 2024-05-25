#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
fi

# Install necessary dependencies
echo "Installing necessary dependencies..."
apt update
apt install -y nginx jq curl
snap install --classic certbot

# Allow OpenSSH and Nginx through UFW
echo "Configuring UFW..."
ufw allow OpenSSH comment "Allow OpenSSH"
ufw allow 'Nginx Full' comment "Allow Nginx"
ufw enable
