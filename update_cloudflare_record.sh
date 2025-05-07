#!/usr/bin/env bash
set -euo pipefail

API_BASEURL="https://api.cloudflare.com/client/v4"

CF_TOKEN="$(cut -d '=' -f2 < $HOME/auth/.cloudflare.token | xargs)"
NEW_IP="$(tailscale ip -4)"
HOSTNAME="record_to_update.ololo.li"
ZONE_NAME="ololo.li"

ZONE_ID_RESULT=$(curl --silent --request GET \
  --url "${API_BASEURL}/zones?name=${ZONE_NAME}" \
  --header "Authorization: Bearer ${CF_TOKEN}" --header 'Content-Type: application/json' | jshon -e result)

[ "[]" == "${ZONE_ID_RESULT}" ] && echo "Could not find zone_id for zone name '${ZONE_NAME}'. Check CF Token permissions"

ZONE_ID=$(echo "${ZONE_ID_RESULT}" | jshon -e 0 -e id -u)
echo "Checking records for zone name '${ZONE_NAME}' (ID=${ZONE_ID})"

# Get all but ".$ZONE_NAME" from $HOSTNAME
RECORD_NAME=${HOSTNAME/.$ZONE_NAME/}
[ "$RECORD_NAME" == "$ZONE_NAME" ] && RECORD_NAME="@"

RECORDS_RESULT=$(curl --silent --request GET \
    --url "${API_BASEURL}/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD_NAME}.${ZONE_NAME}" \
    --header "Authorization: Bearer ${CF_TOKEN}" --header 'Content-Type: application/json' | jshon -e result)

PAYLOAD_DATA='{"content": "'${NEW_IP}'", "name": "'${RECORD_NAME}'", "proxied": false, "type": "A"}'

if [ "[]" == "${RECORDS_RESULT}" ]; then
    echo "No records of type A with the name='${RECORD_NAME}' in the zone='${ZONE_NAME}'. Creating one..."
    curl --silent --request POST \
        --url "${API_BASEURL}/zones/${ZONE_ID}/dns_records" \
        --header "Authorization: Bearer ${CF_TOKEN}" \
        --header 'Content-Type: application/json' \
        --data "${PAYLOAD_DATA}" | jshon
else
    echo "Updating existing record with the name='${RECORD_NAME}' in the zone='${ZONE_NAME}'..."
    # Note: It will update only the first found record. Skipping all others (there are could be more than one type A records with the same name)
    RECORD_ID=$(echo "${RECORDS_RESULT}" | jshon -e 0 -e id -u)
    curl --silent --request PATCH \
        --url "{$API_BASEURL}/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
        --header "Authorization: Bearer ${CF_TOKEN}" \
        --header 'Content-Type: application/json' \
        --data "${PAYLOAD_DATA}" | jshon
fi
echo "✅"
