#!/bin/bash

PG_USER="odoo_user"
PG_HOST="localhost"
PG_PORT="5432"
PG_PASSWORD="odoo_user"  # 如果需要密码，请设置
PG_DB="odoo_16_v2"
BACKUP_DIR="/var/backups/odoo_pg"
DATE=$(date '+%Y-%m-%d-%H-%M-%S')
BACKUP_FILE="$BACKUP_DIR/${PG_DB}_backup_$DATE.sql.gz"

# 数据库
printf "正在备份 PostgreSQL 数据库: %s\n" "$PG_DB"
export PGPASSWORD="$PG_PASSWORD"
pg_dump -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" --no-owner --no-privileges --format=custom --compress=9 "$PG_DB" | gzip > "$BACKUP_FILE"

# Filestore
if [ $? -eq 0 ]; then
    echo "PostgreSQL 数据库备份成功: $BACKUP_FILE"
else
    echo "PostgreSQL 数据库备份失败"
    exit 1
fi

tar -czf $BACKUP_DIR/filestore_odoo_16_v2_$DATE.tar.gz /www/wwwroot/odoo_16/data/filestore/odoo_16_v2

# 模块 & 配置
tar -czf $BACKUP_DIR/odoo_conf_code_$DATE.tar.gz /www/wwwroot/odoo_16/odoo.conf /www/wwwroot/odoo_16/custom_addons
