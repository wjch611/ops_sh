#!/bin/bash

# ====================== 配置区 ======================
FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/a8edcbf7-fac5-45b4-b6e1-da19d0122b8d"
CPU_THRESHOLD=80
MEM_THRESHOLD=80
LOG_FILE="/var/log/monitor.log"
STATUS_FILE="/tmp/monitor_last_status.txt"      # 记录上一次状态（0=正常，1=超标）
LAST_ALERT_TIME_FILE="/tmp/monitor_last_alert.txt"  # 上次告警时间（防重复）
# =================================================

# 获取当前时间（秒）
CURRENT_TIME=$(date +%s)

# 获取 CPU 使用率（整数部分）
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}' | cut -d. -f1)

# 获取内存使用率（整数部分）
MEM_USAGE=$(free | grep Mem | awk '{print $3/$2 * 100.0}' | cut -d. -f1)

# 当前状态：0=正常，1=超标
CURRENT_STATUS=0
if [ "$CPU_USAGE" -gt "$CPU_THRESHOLD" ] || [ "$MEM_USAGE" -gt "$MEM_THRESHOLD" ]; then
    CURRENT_STATUS=1
fi

# 读取上次状态（不存在默认为 0）
LAST_STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo 0)

# 读取上次告警时间（不存在默认为 0）
LAST_ALERT_TIME=$(cat "$LAST_ALERT_TIME_FILE" 2>/dev/null || echo 0)

# 日志记录当前指标
echo "[$(date '+%Y-%m-%d %H:%M:%S')] CPU: $CPU_USAGE% | MEM: $MEM_USAGE% | Status: $CURRENT_STATUS" >> "$LOG_FILE"

# 情况1：有超标 → 发送告警（每5分钟一次）
if [ "$CURRENT_STATUS" -eq 1 ]; then
    if [ $((CURRENT_TIME - LAST_ALERT_TIME)) -ge 300 ]; then
        MSG="【资源超标告警】\nCPU: $CPU_USAGE% (阈值 $CPU_THRESHOLD%)\n内存: $MEM_USAGE% (阈值 $MEM_THRESHOLD%)\n服务器: $(hostname)\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
        curl -X POST -H "Content-Type: application/json" \
            -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"$MSG\"}}" "$FEISHU_WEBHOOK" > /dev/null 2>&1
        echo "$CURRENT_TIME" > "$LAST_ALERT_TIME_FILE"
        echo "告警已发送：$MSG" >> "$LOG_FILE"
    fi
fi

# 情况2：从超标 → 全部恢复 → 发送恢复通知（只发一次）
if [ "$LAST_STATUS" -eq 1 ] && [ "$CURRENT_STATUS" -eq 0 ]; then
    MSG="【资源恢复正常】\nCPU: $CPU_USAGE% | 内存: $MEM_USAGE%\n服务器: $(hostname)\n时间: $(date '+%Y-%m-%d %H:%M:%S')"
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"msg_type\":\"text\",\"content\":{\"text\":\"$MSG\"}}" "$FEISHU_WEBHOOK" > /dev/null 2>&1
    echo "恢复通知已发送：$MSG" >> "$LOG_FILE"
fi

# 更新当前状态到文件（供下次对比）
echo "$CURRENT_STATUS" > "$STATUS_FILE"

exit 0
