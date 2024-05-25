#!/bin/bash

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
fi

# Directory containing your Nginx site configuration files
SOURCE_DIR="../../nginx-server-private/sites"

# Check if source directory is provided
if [ -z "$SOURCE_DIR" ]; then
    echo "Usage: $0 <source_directory>"
    exit 1
fi

# Nginx directories
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

# Copy configuration files to sites-available
cp -p "$SOURCE_DIR"/* "$NGINX_SITES_AVAILABLE/"

# Change permissions to 644 for all files in sites-available
chmod 644 "$NGINX_SITES_AVAILABLE/"*

# Create symbolic links in sites-enabled
for site in "$NGINX_SITES_AVAILABLE"/*; do
    site_name=$(basename "$site")
    ln -sf "$NGINX_SITES_AVAILABLE/$site_name" "$NGINX_SITES_ENABLED/$site_name"
done

# Test Nginx configuration
nginx -t

# Restart Nginx service
if [ $? -eq 0 ]; then
    systemctl restart nginx
    echo "Nginx configuration is valid and the service has been restarted."
else
    echo "Nginx configuration is invalid. Please check the configuration files."
    exit 1
fi
