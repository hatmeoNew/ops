#!/bin/bash

# Configuration
PROD_DB_HOST="localhost"
PROD_DB_PORT="5432"
PROD_DB_NAME="odoo_16_v2"
PROD_DB_USER="odoo_user"
PROD_DB_PASSWORD="odoo_user"

DUMP_FILE="/var/backups/odoo_pg/odoo_16_v2_backup_2025-05-23-01-30-01.sql"

# Export development database password
export PGPASSWORD=$PROD_DB_PASSWORD

# Restore the dump to the database
echo "Restoring dump to database..."
pg_restore -h $PROD_DB_HOST -p $PROD_DB_PORT -U $PROD_DB_USER -d $PROD_DB_NAME -v $DUMP_FILE