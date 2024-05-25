#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

AGENTS_DIR=$(realpath "../../../nginx-server-private/agents")

SCRIPTS_DIR=$(realpath "./scripts")
AUTH_HOOK=$(realpath "${SCRIPTS_DIR}/auth_hook.sh")
CLEANUP_HOOK=$(realpath "${SCRIPTS_DIR}/cleanup_hook.sh")

declare -a AGENTS=()
declare -a DOMAINS=()

checkRequirements() {

    # Check if realpath command is available
    if ! command -v realpath &>/dev/null; then
        echo "Error: 'realpath' command not found. Please make sure it's installed."
        exit 1
    fi

}

GetAgents() {

    # Check if the path exists and is a directory
    if [[ -d "$AGENTS_DIR" ]]; then

        # Initialize the AGENTS array using glob expansion
        AGENTS=("${AGENTS_DIR}"/*)

        # Print the list of agents in a readable format
        echo ""
        echo "List of DynuDNS Agents:"
        for index in "${!AGENTS[@]}"; do
            printf "%d. %s\n" "$((index + 1))" "$(basename ${AGENTS[$index]})"
        done
    else
        echo "Error: Path '$AGENTS_DIR' does not exist or is not a directory."
        exit 1
    fi
}

GetDomains() {

    # Source environment variables
    source ./env || { echo "Failed to source environment variables"; exit 1; }

    # Call Dynu API to get domain information
    local api_response
    api_response=$(curl -s -X GET "https://api.dynu.com/v2/dns" -H "accept: application/json" -H "API-Key: ${API_KEY}") || { echo "Failed to get domains information"; exit 1; }

    # Parse JSON response to extract domain names
    local domain_names
    domain_names=$(echo "$api_response" | jq -r '.domains[].name') || { echo "Failed to parse domain names"; exit 1; }

    # Convert domain names string to an array
    DOMAINS=("${domain_names//$'\n'/ }")
    read -a DOMAINS <<< "$DOMAINS"

    # Print the list of domains
    echo ""
    echo "List of Domains:"
    for domain in "${DOMAINS[@]}"; do
        echo "$(basename ${domain})"
    done
}

GenerateCertificate() {
    local DOMAIN="${1}"
    local EMAIL="${2}"
    local retries=3

    for ((i=0; i<retries; i++)); do
        certbot certonly \
            --manual-public-ip-logging-ok \
            --non-interactive \
            --agree-tos \
            --manual \
            --preferred-challenges=dns \
            --key-type rsa \
            --rsa-key-size 4096 \
            --email "${EMAIL}" \
            --manual-auth-hook "${AUTH_HOOK}" \
            --manual-cleanup-hook "${CLEANUP_HOOK}" \
            -d "${DOMAIN}" \
            -d "*.${DOMAIN}" && break
        echo "Certbot failed for ${DOMAIN}, attempt $((i+1))"
        sleep 10
    done
}

ForceRenewCertificate() {
    local DOMAIN="${1}"
    local EMAIL="${2}"
    local retries=3

    for ((i=0; i<retries; i++)); do
        certbot certonly \
            --force-renew \
            --manual-public-ip-logging-ok \
            --non-interactive \
            --agree-tos \
            --manual \
            --preferred-challenges=dns \
            --key-type rsa \
            --rsa-key-size 4096 \
            --email "${EMAIL}" \
            --manual-auth-hook "${AUTH_HOOK}" \
            --manual-cleanup-hook "${CLEANUP_HOOK}" \
            -d "${DOMAIN}" \
            -d "*.${DOMAIN}" && break
        echo "Certbot force renew failed for ${DOMAIN}, attempt $((i+1))"
        sleep 10
    done
}

GenerateOrRenewCertificates() {
    
    local flag="$1"

    GetAgents

    # Generate or force renew certificates for domains
    for AGENT in "${AGENTS[@]}"; do
        
        cd "${AGENT}" || continue
        echo ""
        echo "Getting Domains for '$(basename ${AGENT})'..."
        GetDomains
        
        for DOMAIN in "${DOMAINS[@]}"; do
            echo ""
            if [ "$flag" == "generate" ]; then
                echo "Generating Certificate for '$DOMAIN'"
                GenerateCertificate "$DOMAIN" "$EMAIL"
            elif [ "$flag" == "renew" ]; then
                echo "Force Renewing Certificate for '$DOMAIN'"
                ForceRenewCertificate "$DOMAIN" "$EMAIL"
            else
                echo "Invalid flag: $flag. Use 'generate' or 'renew'."
                exit 1
            fi
        done
    done
}

main() {
    PS3="Select Option : "
    items=("Generate Certificate" "Force Renew Certificate")

    while true; do
        select item in "${items[@]}" Quit; do
            case $REPLY in
                1)
                    GenerateOrRenewCertificates "generate"
                    break 2
                    ;;
                2)
                    GenerateOrRenewCertificates "renew"
                    break 2
                    ;;
                $((${#items[@]}+1)))
                    echo "Program Exited!"
                    break 2
                    ;;
                *)
                    echo "Invalid Option: $REPLY"
                    ;;
            esac
        done
    done
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
