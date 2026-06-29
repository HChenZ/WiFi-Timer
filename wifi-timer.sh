#!/bin/sh

# Obtain the date of today and the day of the week today
TODAY_DATE=$(date +%Y-%m-%d)
TODAY_WEEKDAY=$(date +%u)

# Fetch the data and set timeout of 10s
API_URL="https://timor.tech/api/holiday/info/$TODAY_DATE"
# First request
JSON=$(wget -qO- --timeout=10 "$API_URL" 2>/dev/null)

RETRY_NEEDED=0
if [ -z "$JSON" ]; then
    RETRY_NEEDED=1
    logger -t "wifi-timer" "First API request failed (empty response)."
elif command -v jsonfilter >/dev/null 2>&1; then
    API_CODE=$(echo "$JSON" | jsonfilter -e '@.code' 2>/dev/null)
    if [ -n "$API_CODE" ] && [ "$API_CODE" != "0" ]; then
        RETRY_NEEDED=1
        logger -t "wifi-timer" "API returned error code: $API_CODE."
    fi
fi

# Retry after 5s if needed
if [ "$RETRY_NEEDED" -eq 1 ]; then
    logger -t "wifi-timer" "First API request failed, retrying in 5s..."
    sleep 5
    JSON=$(wget -qO- --timeout=10 "$API_URL" 2>/dev/null)
fi

IS_WORKDAY=0

if [ -n "$JSON" ] && command -v jsonfilter >/dev/null 2>&1; then
    API_CODE=$(echo "$JSON" | jsonfilter -e '@.code' 2>/dev/null)
    if [ -n "$API_CODE" ] && [ "$API_CODE" != "0" ]; then
        # API still returning error code, fallback to weekday check
        logger -t "wifi-timer" "API still returning error code ($API_CODE) after retry, fallback to weekday check."
        if [ "$TODAY_WEEKDAY" -ne 6 ] && [ "$TODAY_WEEKDAY" -ne 7 ]; then
            IS_WORKDAY=1
        fi
    else
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
