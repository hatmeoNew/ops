#!/bin/bash

# 配置参数
PG_USER="odoo_user"
PG_HOST="localhost"
PG_PORT="5432"
PG_PASSWORD="odoo_user"  # 如果需要密码，请设置
PG_DB="odoo_16_v2"
BACKUP_DIR="/var/backups/odoo_pg"
DATE=$(date '+%Y-%m-%d-%H-%M-%S')
BACKUP_FILE="$BACKUP_DIR/${PG_DB}_backup_$DATE.sql.gz"

# 创建备份目录（如不存在）
mkdir -p "$BACKUP_DIR"

# 备份数据库并压缩
export PGPASSWORD="$PG_PASSWORD"
pg_dump -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" --no-owner --no-privileges --format=custom --compress=9 "$PG_DB" | gzip > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "PostgreSQL 数据库备份成功: $BACKUP_FILE"
else
    echo "PostgreSQL 数据库备份失败"
    exit 1
fi