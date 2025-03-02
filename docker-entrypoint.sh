#!/bin/bash
set -e

# Wait for the database to be ready
echo "Waiting for database connection..."
until mysql -h database -u ${DB_USERNAME} -p${DB_PASSWORD} -e "SELECT 1"; do
  sleep 1
done

# Check if the database is initialized
DB_INITIALIZED=$(mysql -h database -u ${DB_USERNAME} -p${DB_PASSWORD} -D ${DB_DATABASE} -e "SHOW TABLES" 2>/dev/null || echo "")

if [ -z "$DB_INITIALIZED" ]; then
    echo "Initializing database..."
    php artisan migrate --seed --force
    php artisan p:environment:setup --no-interaction \
      --author=$APP_SERVICE_AUTHOR \
      --url=$APP_URL \
      --timezone=$APP_TIMEZONE \
      --cache=redis \
      --session=redis \
      --queue=redis \
      --redis-host=cache \
      --redis-port=6379 \
      --settings-ui=1
    
    php artisan p:environment:database --no-interaction \
      --host=database \
      --port=3306 \
      --database=${DB_DATABASE} \
      --username=${DB_USERNAME} \
      --password=${DB_PASSWORD}
    
    # Create admin user if no users exist
    USER_COUNT=$(mysql -h database -u ${DB_USERNAME} -p${DB_PASSWORD} -D ${DB_DATABASE} -e "SELECT COUNT(*) FROM users" | grep -v "COUNT" || echo "0")
    
    if [ "$USER_COUNT" = "0" ]; then
        echo "Creating default admin user..."
        php artisan p:user:make --admin --name-first=Admin --name-last=User --email=admin@example.com --password=Password123 --no-interaction
    fi
fi

# Start panel services
echo "Starting Pterodactyl Panel..."
exec php-fpm & nginx -g "daemon off;"