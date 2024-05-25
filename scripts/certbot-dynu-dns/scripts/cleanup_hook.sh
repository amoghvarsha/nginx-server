#!/bin/bash

source ./env #Load the API_KEY

# Get domainID
dns=$(curl -s -X GET https://api.dynu.com/v2/dns -H "accept: application/json" -H "API-Key: $API_KEY")
if [ $? -ne 0 ]; then
    echo "Failed to get domain information"
    exit 1
fi

domainID=$(echo $dns | jq -r ".domains[] | select(.name==\"$CERTBOT_DOMAIN\") | .id")
if [ -z "$domainID" ]; then
    echo "Domain ID not found"
    exit 1
fi

while true; do
    records=$(curl -s -X GET "https://api.dynu.com/v2/dns/$domainID/record" -H "accept: application/json" -H "API-Key: $API_KEY")
    identifier=$(echo $records | jq -r '.dnsRecords[] | select(.nodeName=="_acme-challenge") | .id' | head -n 1)
    
    if [ -z "$identifier" ]; then
        break
    fi

    echo "Delete: $identifier"
    curl -s -X DELETE "https://api.dynu.com/v2/dns/$domainID/record/$identifier" -H "accept: application/json" -H "API-Key: $API_KEY"
    
    if [ $? -ne 0 ]; then
        echo "Failed to delete DNS record $identifier"
        exit 1
    fi
done
