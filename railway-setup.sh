#!/bin/bash
set -e

echo "=== Frappe CRM Railway Site Setup ==="
echo "This script creates and configures the CRM site."
echo "It should only be run ONCE after the initial deployment."
echo ""

BENCH_DIR="/home/frappe/frappe-bench"
SITE_NAME="${SITE_NAME:-crm.localhost}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-admin}"
DB_ROOT_PASSWORD="${DB_ROOT_PASSWORD:-}"

cd $BENCH_DIR

# -------------------------------------------------------
# Create new site
# -------------------------------------------------------
echo "Creating site: $SITE_NAME"

su frappe -c "bench new-site $SITE_NAME \
    --force \
    --mariadb-root-password '$DB_ROOT_PASSWORD' \
    --admin-password '$ADMIN_PASSWORD' \
    --no-mariadb-socket"

# -------------------------------------------------------
# Install CRM app
# -------------------------------------------------------
echo "Installing CRM app..."
su frappe -c "bench --site $SITE_NAME install-app crm"

# -------------------------------------------------------
# Configure site for production
# -------------------------------------------------------
echo "Configuring site for production..."
su frappe -c "bench --site $SITE_NAME set-config server_script_enabled 1"
su frappe -c "bench --site $SITE_NAME set-config mute_emails 1"
su frappe -c "bench use $SITE_NAME"

# -------------------------------------------------------
# Build assets
# -------------------------------------------------------
echo "Building assets..."
su frappe -c "bench build --app crm"

echo ""
echo "============================================="
echo "✅ Frappe CRM site setup complete!"
echo ""
echo "Site: $SITE_NAME"
echo "Username: Administrator"
echo "Password: $ADMIN_PASSWORD"
echo ""
echo "NEXT STEPS:"
echo "1. Exit this shell"
echo "2. In Railway settings, remove the start command override"
echo "3. Set HTTP port to 80"
echo "4. Redeploy the service"
echo "============================================="
