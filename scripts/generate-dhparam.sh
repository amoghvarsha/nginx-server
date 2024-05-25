#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

LETSENCRYPT_DIR="/etc/letsencrypt"
ARCHIVE_DIR="$LETSENCRYPT_DIR/archive"
LIVE_DIR="$LETSENCRYPT_DIR/live"

TMP_DHPARAM_FILE=$(mktemp /tmp/dhparam.XXXXXX.pem)

GetDomains() {
    # Get the list of directories in LIVE_DIR and filter out README
    local all_domains
    all_domains=($(ls -d ${LIVE_DIR}/* 2>/dev/null | xargs -n 1 basename))
    
    DOMAINS=()
    for domain in "${all_domains[@]}"; do
        if [[ "$domain" != "README" ]]; then
            DOMAINS+=("$domain")
        fi
    done

    echo
    # Print the list of domains
    echo "List of DynuDNS DOMAINS:"
    for domain in "${DOMAINS[@]}"; do
        echo "- $domain"
    done
}


Generate() {
    local domain="$1"

    echo
    echo "Generating dhparam key for ${domain}"

    head -c 1 </dev/urandom > /dev/null

    # Generate the DH parameters, capturing the return status
    local dhparam_status
    dhparam_status=$(openssl dhparam -out ${TMP_DHPARAM_FILE} 4096 2>&1)

    # Check the return status and print the appropriate message
    if [ $? -eq 0 ]; then
        echo "DH parameters generated successfully."
    else
        echo "Failed to generate DH parameters: $dhparam_status"
        exit 1
    fi
}

Move() {

    local domain="$1"
    local src_dhparam_file="$2"
    local dst_dhparam_file="$3"

    echo "Moving dhparam key to ${domain}"

    mv "${TMP_DHPARAM_FILE}" "${src_dhparam_file}"
    chown root:root "${src_dhparam_file}"

    rm -f "${dst_dhparam_file}"
    ln -s "${src_dhparam_file}" "${dst_dhparam_file}"

    echo "Done!"
}


main() {
    GetDomains

    for domain in "${DOMAINS[@]}"; do
        local domain_archive_dir="${ARCHIVE_DIR}/${domain}"
        local domain_live_dir="${LIVE_DIR}/${domain}"

        # Determine the next index for dhparam file
        local index
        index=$(ls ${domain_archive_dir} | grep -E "dhparam.*pem" | wc -l)
        index=$((index + 1))

        local src_dhparam_file="${domain_archive_dir}/dhparam${index}.pem"
        local dst_dhparam_file="${domain_live_dir}/dhparam.pem"

        echo
        echo "DOMAIN: ${domain}"
        echo "SRC DHPARAM FILE: ${src_dhparam_file}"
        echo "DST DHPARAM FILE: ${dst_dhparam_file}"

        Generate "${domain}"
        Move "${domain}" "${src_dhparam_file}" "${dst_dhparam_file}"

        echo
    done

    # Clean up temporary file
    rm -f "${TMP_DHPARAM_FILE}"
}

# Check if the script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root."
    exit 1
else
    main
    exit 0
fi
