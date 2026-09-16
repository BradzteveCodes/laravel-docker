#!/bin/sh

set -e

APP_URL="${APP_HEALTH_URL:-http://127.0.0.1}"

if ! curl \
    --fail \
    --silent \
    --show-error \
    --max-time 5 \
    "$APP_URL" > /dev/null; then

    echo "Health check failed: $APP_URL"
    exit 1
fi

echo "Health check passed: $APP_URL"
exit 0