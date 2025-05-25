#!/bin/bash

# Configuration
PROD_DB_HOST="localhost"
PROD_DB_PORT="5432"
PROD_DB_NAME="odoo_16_v2"
PROD_DB_USER="odoo_user"
PROD_DB_PASSWORD="odoo_user"

DEV_DB_HOST="localhost"
DEV_DB_PORT="5432"
DEV_DB_NAME="odoo_dev"
DEV_DB_USER="odoo_user"
DEV_DB_PASSWORD="odoo_user"

NOW=$(date +"%Y-%m-%d-%H-%M-%S")

# Back the development database
echo "Backing up development database..."

# Export development database password
export PGPASSWORD=$DEV_DB_PASSWORD
# Back the development database sql file path
DEV_DUMP_FILE="./db/$DEV_DB_NAME-$NOW.sql"
pg_dump -h $DEV_DB_HOST -p $DEV_DB_PORT -U $DEV_DB_USER -F c -b -v -f $DEV_DUMP_FILE $DEV_DB_NAME

# Check if the backup was successful
if [ $? -ne 0 ]; then
    echo "Failed to backup the development database."
    exit 1
fi

# Temporary dump file
DUMP_FILE="./db/prod_db_dump_$NOW.sql"
LOG_FILE="./db/prod_db_dump_$NOW.log"

# Export production database password
export PGPASSWORD=$PROD_DB_PASSWORD

# Dump the production database
echo "Dumping production database..."
pg_dump -h $PROD_DB_HOST -p $PROD_DB_PORT -U $PROD_DB_USER -F c -b -v -f $DUMP_FILE $PROD_DB_NAME

# Check if the dump was successful
if [ $? -ne 0 ]; then
    echo "Failed to dump the production database."
    exit 1
fi

# Export development database password
export PGPASSWORD=$DEV_DB_PASSWORD

# Terminate all connections to the development database
echo "Terminating all connections to the development database..."
psql -h $DEV_DB_HOST -p $DEV_DB_PORT -U $DEV_DB_USER -d postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '$DEV_DB_NAME'
  AND pid <> pg_backend_pid();
" 2>&1 | tee -a $LOG_FILE

# Drop the development database
echo "Dropping development database...$DEV_DB_NAME"
psql -h $DEV_DB_HOST -p $DEV_DB_PORT -U $DEV_DB_USER -d postgres -c "DROP DATABASE IF EXISTS $DEV_DB_NAME;"

# Create the development database
echo "Creating development database..."
psql -h $DEV_DB_HOST -p $DEV_DB_PORT -U $DEV_DB_USER -d postgres -c "CREATE DATABASE $DEV_DB_NAME;"

# Restore the dump to the development database
echo "Restoring dump to development database..."
pg_restore -h $DEV_DB_HOST -p $DEV_DB_PORT -U $DEV_DB_USER -d $DEV_DB_NAME -v $DUMP_FILE

# Check if the restore was successful
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo "Failed to restore the dump to the development database. check $LOG_FILE for more details."
    exit 1
fi

# Clean up
echo "Cleaning up..."
rm $DUMP_FILE

echo "Database sync from production to development completed successfully."