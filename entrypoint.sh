#!/bin/bash
set -e

echo "=== Frappe CRM Railway Entrypoint ==="

BENCH_DIR="/home/frappe/frappe-bench"
SITE_NAME="${SITE_NAME:-crm.localhost}"

# -------------------------------------------------------
# Configure database and redis connections
# -------------------------------------------------------
cd $BENCH_DIR

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
    su frappe -c "bench set-config -g redis_cache $REDIS_CACHE"
fi

if [ -n "$REDIS_QUEUE" ]; then
    su frappe -c "bench set-config -g redis_queue $REDIS_QUEUE"
    su frappe -c "bench set-config -g redis_socketio $REDIS_QUEUE"
fi

# Set socketio port
su frappe -c "bench set-config -gp socketio_port 9000"

# -------------------------------------------------------
# Generate apps list
# -------------------------------------------------------
echo "Generating apps list..."
ls -1 apps > sites/apps.txt

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
    echo "Please run railway-setup.sh to create the site."
    echo "You can do this via Railway shell:"
    echo "  bash /home/frappe/railway-setup.sh"
    echo "============================================="
else
    echo "Site '$SITE_NAME' already exists."
    su frappe -c "bench use $SITE_NAME"
fi

# -------------------------------------------------------
# Start all services via Supervisor
# -------------------------------------------------------
echo "Starting all services via Supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/frappe.conf
