#!/bin/bash

source ./env # Load the API_KEY

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

# Create record
record_data=$(jq -n --arg nodeName "_acme-challenge" --arg textData "$CERTBOT_VALIDATION" '{
    nodeName: $nodeName,
    recordType: "TXT",
    ttl: 60,
    state: true,
    group: "",
    textData: $textData
}')

result_create=$(curl -s -X POST "https://api.dynu.com/v2/dns/$domainID/record" -H "accept: application/json" -H "Content-Type: application/json" -d "$record_data" -H "API-Key: $API_KEY")
if [ $? -ne 0 ]; then
    echo "Failed to create DNS record"
    exit 1
fi

echo $result_create

sleep 30
