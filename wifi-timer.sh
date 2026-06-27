#!/bin/sh

# Obtain the date of today and the day of the week today
TODAY_DATE=$(date +%Y-%m-%d)
TODAY_WEEKDAY=$(date +%u)

# Fetch the data and set timeout of 10s
API_URL="http://timor.tech/api/holiday/info/$TODAY_DATE"
# First request
JSON=$(wget -qO- --timeout=10 "$API_URL" 2>/dev/null)
# If first request failed, retry in 5s
if [ -z "$JSON" ]; then
    logger -t "wifi-timer" "First API request failed, retrying in 5s..."
    sleep 5
    JSON=$(wget -qO- --timeout=10 "$API_URL" 2>/dev/null)
fi

IS_WORKDAY=0

if [ -n "$JSON" ] && command -v jsonfilter >/dev/null 2>&1; then
    TYPE=$(echo "$JSON" | jsonfilter -e '@.type.type' 2>/dev/null)
    if [ -z "$TYPE" ]; then
        # Parsing failed, fallback to weekday check
        logger -t "wifi-timer" "API parse failed, fallback to weekday check"
        if [ "$TODAY_WEEKDAY" -ne 6 ] && [ "$TODAY_WEEKDAY" -ne 7 ]; then
            IS_WORKDAY=1
        fi
    elif [ "$TYPE" = "0" ] || [ "$TYPE" = "3" ]; then
        IS_WORKDAY=1
    fi
else
    # API unavailable, fallback to weekday check
    logger -t "wifi-timer" "API unavailable, fallback to weekday check"
    if [ "$TODAY_WEEKDAY" -ne 6 ] && [ "$TODAY_WEEKDAY" -ne 7 ]; then
        IS_WORKDAY=1
    fi
fi

# Execute control
if [ "$IS_WORKDAY" -eq 1 ]; then
    # Today is a work day
    logger -t "wifi-timer" "Today ($TODAY_DATE) is a work day. Disabling WiFi..."
    touch /tmp/school_net_off
else
    # Today is a holiday/weekend
    logger -t "wifi-timer" "Today ($TODAY_DATE) is a holiday/weekend. WiFi stays active."
    rm -f /tmp/school_net_off 2>/dev/null
fi