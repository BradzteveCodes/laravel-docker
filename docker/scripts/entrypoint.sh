#!/bin/sh

set -e

echo "Starting Laravel production container..."

cd /var/www/html

# ------------------------------------------------------------
# Ensure required Laravel directories exist
# ------------------------------------------------------------

mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache

# ------------------------------------------------------------
# Permissions
# ------------------------------------------------------------

chown -R www-data:www-data \
    storage \
    bootstrap/cache

chmod -R 775 \
    storage \
    bootstrap/cache

# ------------------------------------------------------------
# Verify Laravel application key
# ------------------------------------------------------------

if [ -z "${APP_KEY:-}" ]; then
    echo "ERROR: APP_KEY is not set."
    exit 1
fi

# ------------------------------------------------------------
# Verify application configuration
# ------------------------------------------------------------

php artisan about --only=environment

# ------------------------------------------------------------
# Optional database connectivity check
# ------------------------------------------------------------

if [ "${CHECK_DATABASE_ON_STARTUP:-true}" = "true" ]; then

    echo "Checking database connection..."

    php artisan db:show > /dev/null

    echo "Database connection successful."

fi

# ------------------------------------------------------------
# Start the requested container process
# ------------------------------------------------------------

echo "Laravel container initialization completed."

exec "$@"