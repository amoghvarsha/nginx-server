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

    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo "List of DynuDNS DOMAINS: ${DOMAINS[@]}"
    echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
    echo
}

Generate() {
    local domain="$1"

    echo "Generating dhparam key for ${domain}"

    head -c 1 </dev/urandom > /dev/null

    openssl dhparam -out ${TMP_DHPARAM_FILE} 4096

    echo "Done!"
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

        echo "DOMAIN: ${domain}"
        echo "SRC DHPARAM FILE: ${src_dhparam_file}"
        echo "DST DHPARAM FILE: ${dst_dhparam_file}"
        echo

        Generate "${domain}"
        Move "${domain}" "${src_dhparam_file}" "${dst_dhparam_file}"

        echo
    done

    # Clean up temporary file
    rm -f "${TMP_DHPARAM_FILE}"
}

if [ "$EUID" -ne 0 ]
then
    echo "Please run as root"

    exit 2

else
    main

    exit 0
fi
