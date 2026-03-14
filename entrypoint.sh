#!/bin/bash
set -e

echo "=== Frappe CRM Railway Entrypoint ==="

BENCH_DIR="/home/frappe/frappe-bench"
SITE_NAME="${SITE_NAME:-crm.localhost}"

cd $BENCH_DIR

# -------------------------------------------------------
# Initialize sites directory (critical for fresh volumes)
# -------------------------------------------------------
echo "Initializing sites directory..."

# Create common_site_config.json if missing (fresh volume)
if [ ! -f sites/common_site_config.json ]; then
    echo "{}" > sites/common_site_config.json
    chown frappe:frappe sites/common_site_config.json
    echo "Created empty common_site_config.json"
fi

# Generate apps.txt from installed apps (MUST be before any bench commands)
echo "Generating apps list..."
ls -1 apps > sites/apps.txt
chown frappe:frappe sites/apps.txt
echo "Apps found: $(cat sites/apps.txt | tr '\n' ', ')"

# -------------------------------------------------------
# Configure database and redis connections
# -------------------------------------------------------
echo "Configuring site connection settings..."

# Set MariaDB connection
if [ -n "$DB_HOST" ]; then
    su frappe -c "bench set-config -g db_host $DB_HOST"
fi

if [ -n "$DB_PORT" ]; then
    su frappe -c "bench set-config -gp db_port $DB_PORT"
fi

# Set Redis connections
if [ -n "$REDIS_CACHE" ]; then
    su frappe -c "bench set-config -g redis_cache '$REDIS_CACHE'"
fi

if [ -n "$REDIS_QUEUE" ]; then
    su frappe -c "bench set-config -g redis_queue '$REDIS_QUEUE'"
    su frappe -c "bench set-config -g redis_socketio '$REDIS_QUEUE'"
fi

# Set socketio port
su frappe -c "bench set-config -gp socketio_port 9000"

# -------------------------------------------------------
# Setup nginx config
# -------------------------------------------------------
echo "Setting up nginx..."
cp /etc/nginx/conf.d/frappe.conf /etc/nginx/conf.d/default.conf 2>/dev/null || true

# -------------------------------------------------------
# Check if site needs to be created
# -------------------------------------------------------
if [ ! -d "$BENCH_DIR/sites/$SITE_NAME" ]; then
    echo "============================================="
    echo "Site '$SITE_NAME' not found."
    echo "Auto-creating site..."
    echo "============================================="
    
    # Set MariaDB root password for site creation
    if [ -n "$DB_ROOT_PASSWORD" ]; then
        su frappe -c "bench new-site $SITE_NAME \
            --mariadb-root-password '$DB_ROOT_PASSWORD' \
            --admin-password '${ADMIN_PASSWORD:-admin}' \
            --install-app crm \
            --set-default"
        echo "Site '$SITE_NAME' created successfully!"
    else
        echo "WARNING: DB_ROOT_PASSWORD not set. Cannot auto-create site."
        echo "Please run: bash /home/frappe/railway-setup.sh"
    fi
else
    echo "Site '$SITE_NAME' already exists."
    su frappe -c "bench use $SITE_NAME"
fi

# -------------------------------------------------------
# Start all services via Supervisor
# -------------------------------------------------------
echo "Starting all services via Supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/frappe.conf
