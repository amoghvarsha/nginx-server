#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Directory containing your Nginx site configuration files
SOURCE_DIR=$(realpath "../../nginx-server-private/sites")

# Nginx sites-available and sites-enabled directories
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

checkRequirements() {
    # Check if realpath command is available
    if ! command -v realpath &>/dev/null; then
        echo "Error: 'realpath' command not found. Please make sure it's installed."
        exit 1
    fi
}

main() {

    # Copy configuration files to sites-available
    for file in "$SOURCE_DIR"/*; do
        file_name=$(basename "$file")
        destination="$NGINX_SITES_AVAILABLE/$file_name"

        if [ -e "$destination" ]; then
            echo -n -e "\nConfiguration file '$file_name' already exists. Overwrite (y/n)? "
            read -r -n 1 choice
            echo
            case $choice in
                y|Y)
                    cp -p "$file" "$destination"
                    ;;
                *)
                    echo "Skipping '$file_name'."
                    continue
                    ;;
            esac
        else
            cp -p "$file" "$destination"
        fi

        # Change permissions to 644 for the copied file
        chmod 644 "$destination"

        # Ask if the user wants to enable the configuration file
        echo -n -e "\nEnable configuration file '$file_name' (y/n)? "
        read -r -n 1 choice
        echo
        case $choice in
            y|Y)
                ln -sf "$destination" "$NGINX_SITES_ENABLED/$file_name"
                ;;
            *)
                echo "Skipping enabling '$file_name'."
                ;;
        esac
    done

    echo
    # Test Nginx configuration
    nginx -t

    # Restart Nginx service
    if [ $? -eq 0 ]; then
        systemctl restart nginx
        echo -e "\nNginx configuration is valid and the service has been restarted."
    else
        echo -e "\nNginx configuration is invalid. Please check the configuration files."
        exit 1
    fi
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
else
    checkRequirements
    main
    exit 0
fi
