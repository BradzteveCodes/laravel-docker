#!/bin/sh

set -e

echo "=========================================="
echo " Laravel Production Deployment"
echo "=========================================="

cd /var/www/html

echo
echo "1. Running database migrations..."
php artisan migrate --force

echo
echo "2. Clearing old Laravel caches..."
php artisan optimize:clear

echo
echo "3. Rebuilding Laravel caches..."
php artisan optimize

echo
echo "4. Verifying Laravel application..."
php artisan about --only=environment

echo
echo "=========================================="
echo " Deployment tasks completed successfully."
echo "=========================================="