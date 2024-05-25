#!/bin/bash

SCRIPTS_PATH=$(realpath "./scripts")
AUTH_HOOK=$(realpath "${SCRIPTS_PATH}/auth_hook.sh")
CLEANUP_HOOK=$(realpath "${SCRIPTS_PATH}/cleanup_hook.sh")

AGENTS_PATH=$(realpath "../../../nginx-server-private/agents")

GetAgents() {
    AGENTS=("$(ls -d "${AGENTS_PATH}"/*)")
    AGENTS=("${AGENTS//$'\n'/ }")
    read -a AGENTS <<< "$AGENTS"


    echo "List of DynuDNS Agents: ${AGENTS[@]}"
}

GetDomains() {
    source ./env
    APP_JSON="$(curl -s -X GET "https://api.dynu.com/v2/dns" -H "accept: application/json" -H "API-Key: ${API_KEY}")"
    if [ $? -ne 0 ]; then
        echo "Failed to get domains information"
        exit 1
    fi

    DOMAINS="$(echo $APP_JSON | jq -r '.domains[].name')"
    DOMAINS=("${DOMAINS//$'\n'/ }")
    read -a DOMAINS <<< "$DOMAINS"
    echo "List of Domains: ${DOMAINS[@]}"
}

Generate() {
    local DOMAIN="${1}"
    local EMAIL="${2}"
    retries=3
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

GenerateCertificate() {
    GetAgents
    echo ""
    for AGENT in "${AGENTS[@]}"; do
        cd "${AGENT}" || continue
        GetDomains
        echo ""
        for DOMAIN in "${DOMAINS[@]}"; do
            echo "Generating Certificate for '${DOMAIN}'"
            Generate "${DOMAIN}" "${EMAIL}"
            echo ""
        done
        cd "${BASE_DIR}" || exit
        echo ""
    done
}

ForceRenew() {
    local DOMAIN="${1}"
    local EMAIL="${2}"
    retries=3
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

ForceRenewCertificate() {
    GetAgents
    echo ""
    for AGENT in "${AGENTS[@]}"; do
        cd "${AGENT}" || continue
        GetDomains
        echo ""
        for DOMAIN in "${DOMAINS[@]}"; do
            echo "Force Renewing Certificate for '${DOMAIN}'"
            ForceRenew "${DOMAIN}" "${EMAIL}"
            echo ""
        done
        cd "${BASE_DIR}" || exit
        echo ""
    done
}

main() {
    PS3="Select Option : "
    items=("Generate Certificate" "Force Renew Certificate")

    while true; do
        select item in "${items[@]}" Quit; do
            case $REPLY in
                1)
                    GenerateCertificate
                    break 2
                    ;;
                2)
                    ForceRenewCertificate
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

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 2
else
    main
    exit 0
fi
