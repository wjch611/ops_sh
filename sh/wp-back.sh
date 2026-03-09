#!/bin/bash

set -euo pipefail

# ====================== 配置 ======================
DB_NAME="wordpress"

BACKUP_DIR="/home/devops/wp_backup"
RETENTION_DAYS=7

REMOTE_USER="oem"
REMOTE_IP="192.168.56.1"
REMOTE_PATH="/home/oem/wp_backup_received"

FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/xxxxx"

DEBUG=true
# ==================================================

DATE=$(date +%Y-%m-%d_%H-%M-%S)
WORK_DIR="$BACKUP_DIR/tmp_$DATE"
FINAL_FILE="$BACKUP_DIR/backup-$DATE.tar.gz"
LOG_FILE="$BACKUP_DIR/backup.log"

mkdir -p "$BACKUP_DIR"

log() {
    MSG="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$MSG" | tee -a "$LOG_FILE"
}

debug() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1" | tee -a "$LOG_FILE"
    fi
}

run_cmd() {
    debug "$1"
    eval "$1" >> "$LOG_FILE" 2>&1
}

log "========== WordPress 备份开始 =========="

# 创建临时目录
run_cmd "mkdir -p $WORK_DIR"

# ---------------- 数据库备份 ----------------
log "备份数据库..."

run_cmd "mysqldump --single-transaction --quick $DB_NAME > $WORK_DIR/wordpress.sql"

log "数据库备份完成"

# ---------------- 复制网站目录 ----------------
log "复制网站目录..."

run_cmd "cp -a /var/www/html $WORK_DIR/"

log "网站文件复制完成"

# ---------------- 打包 ----------------
log "开始压缩备份..."

run_cmd "tar -czf $FINAL_FILE -C $WORK_DIR ."

log "压缩完成"

# 删除临时目录
run_cmd "rm -rf $WORK_DIR"

# ---------------- 同步远程 ----------------
log "准备远程备份目录..."

run_cmd "ssh $REMOTE_USER@$REMOTE_IP 'mkdir -p $REMOTE_PATH'"

log "开始 rsync..."

run_cmd "rsync -avz $FINAL_FILE $REMOTE_USER@$REMOTE_IP:$REMOTE_PATH/"

log "远程同步完成"

# ---------------- 清理旧备份 ----------------
log "清理旧备份..."

run_cmd "find $BACKUP_DIR -name 'backup-*.tar.gz' -mtime +$RETENTION_DAYS -delete"

log "清理完成"

# ---------------- 计算大小 ----------------
SIZE=$(du -sh "$FINAL_FILE" | awk '{print $1}')

log "备份文件大小: $SIZE"

# ---------------- 飞书通知 ----------------
log "发送飞书通知..."

curl -s -X POST -H "Content-Type: application/json" \
-d "{
  \"msg_type\": \"text\",
  \"content\": {
    \"text\": \"【WordPress备份】\n✅ 成功\n文件: backup-$DATE.tar.gz\n大小: $SIZE\n服务器: $(hostname)\n时间: $(date '+%Y-%m-%d %H:%M:%S')\"
  }
}" "$FEISHU_WEBHOOK" >> "$LOG_FILE" 2>&1

log "========== 备份完成 =========="

exit 0
