#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

checkRequirements() {
    # Check if openssl is available
    if ! command -v openssl &> /dev/null; then
        echo "openssl could not be found. Please install openssl and try again."
        exit 1
    fi

    # Check if required directories exist
    if [[ ! -d /etc/ssl/certs || ! -d /etc/ssl/private ]]; then
        echo "/etc/ssl/certs or /etc/ssl/private directories do not exist."
        exit 1
    fi
}

main() {

    # Create a temporary file for the OpenSSL config
    tmpfile=$(mktemp)
    cat <<EOF >"$tmpfile"
[dn]
CN=default-server
[req]
distinguished_name = dn
[EXT]
subjectAltName=DNS:default-server
keyUsage=digitalSignature
extendedKeyUsage=serverAuth
EOF

    # Generate the certificate and key
    openssl req -x509 -out /etc/ssl/certs/default_server.crt -keyout /etc/ssl/private/default_server.key \
      -newkey rsa:2048 -nodes -sha256 -subj '/CN=default-server' -extensions EXT -config "$tmpfile"

    # Clean up the temporary file
    rm -f "$tmpfile"

    # Set ownership and permissions
    chown root:root /etc/ssl/certs/default_server.crt
    chown root:root /etc/ssl/private/default_server.key

    chmod 644 /etc/ssl/certs/default_server.crt
    chmod 600 /etc/ssl/private/default_server.key  # Private key should have restricted permissions

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
