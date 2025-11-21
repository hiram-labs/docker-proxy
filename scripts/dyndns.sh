#!/bin/sh
#
# Name.com Dynamic DNS Updater
#
# Updates an A record so that your domain always resolves
# to the current public IPv4 of the host.
#
# Updates three A records: @ www *
#
# Environment:
#   NAMECOM_USERNAME      Name.com account username
#   NAMECOM_API_TOKEN     API token from Name.com
#   DYNDNS_DOMAIN         Domain (example.com)
#

set -eu

API="https://api.name.com/v4"
LOG_TAG="[dyndns]"
CURL="curl -sS --fail"
CACHE_FILE="/tmp/dyndns_last_ip"

# Hard-coded A records to maintain
RECORDS=(
  "@"
  "www"
  "*"
)

log() {
    echo "$LOG_TAG $1"
}

fatal() {
    echo "$LOG_TAG [FATAL] $1" >&2
    exit 1
}

validate_env() {
    : "${NAMECOM_USERNAME:?NAMECOM_USERNAME missing}"
    : "${NAMECOM_API_TOKEN:?NAMECOM_API_TOKEN missing}"
    : "${DYNDNS_DOMAIN:?DYNDNS_DOMAIN missing}"
}

auth_header() {
    printf "%s:%s" "$NAMECOM_USERNAME" "$NAMECOM_API_TOKEN" | base64
}

get_public_ip() {
    IP=$($CURL -4 ifconfig.me || true)
    [ -z "$IP" ] && fatal "Unable to retrieve public IPv4 address"
    echo "$IP"
}

check_cached_ip() {
    if [ -f "$CACHE_FILE" ]; then
        LAST_IP=$(cat "$CACHE_FILE")
        if [ "$LAST_IP" = "$1" ]; then
            log "IP unchanged from cache ($1). Skipping Name.com API calls."
            exit 0
        fi
    fi
}

update_cache() {
    echo "$1" > "$CACHE_FILE"
    log "Local IP cache updated."
}

fetch_records() {
    $CURL \
        -H "Authorization: Basic $(auth_header)" \
        "$API/domains/$DYNDNS_DOMAIN/records"
}

create_record() {
    HOST="$1"
    IP="$2"

    log "Creating A record: host='$HOST' → $IP"

    $CURL -X POST \
        -H "Authorization: Basic $(auth_header)" \
        -H "Content-Type: application/json" \
        -d "{\"host\":\"$HOST\",\"type\":\"A\",\"answer\":\"$IP\",\"ttl\":300}" \
        "$API/domains/$DYNDNS_DOMAIN/records" \
        >/dev/null

    log "Created host='$HOST'."
}

update_record() {
    ID="$1"
    HOST="$2"
    IP="$3"

    log "Updating A record ID=$ID host='$HOST' → $IP"

    $CURL -X PUT \
        -H "Authorization: Basic $(auth_header)" \
        -H "Content-Type: application/json" \
        -d "{\"answer\":\"$IP\",\"ttl\":300}" \
        "$API/domains/$DYNDNS_DOMAIN/records/$ID" \
        >/dev/null

    log "Updated host='$HOST'."
}

process_record() {
    HOST="$1"
    PUBLIC_IP="$2"
    RECORDS_JSON="$3"

    RECORD=$(echo "$RECORDS_JSON" | jq -r --arg h "$HOST" --arg d "$DYNDNS_DOMAIN" '
    (.records // [])[] |
    select(
        .type=="A" and (
        (.host // "") == $h or ($h=="@" and (.fqdn // "") == ($d + "."))
        )
    )
    ')

    ID=$(echo "$RECORD" | jq -r '.id // empty')
    CURRENT_IP=$(echo "$RECORD" | jq -r '.answer // empty')

    if [ -z "$ID" ]; then
        create_record "$HOST" "$PUBLIC_IP"
        return
    fi

    log "Found host='$HOST': ID=$ID CurrentIP=$CURRENT_IP"

    if [ "$CURRENT_IP" = "$PUBLIC_IP" ]; then
        log "No update needed for '$HOST'."
        return
    fi

    update_record "$ID" "$HOST" "$PUBLIC_IP"
}

main() {
    validate_env

    PUBLIC_IP=$(get_public_ip)
    log "Detected public IPv4: $PUBLIC_IP"

    check_cached_ip "$PUBLIC_IP"

    RECORDS_JSON=$(fetch_records)

    for HOST in "${RECORDS[@]}"; do
        log "Processing host='$HOST'…"
        process_record "$HOST" "$PUBLIC_IP" "$RECORDS_JSON"
    done

    update_cache "$PUBLIC_IP"

    log "All records processed."
}

main "$@"
