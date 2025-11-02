#!/bin/bash
# DNS API 服务健康检查和自动修复脚本（服务器端）
# 部署位置: /opt/monitor/check-dnsapi.sh
# 运行方式: cron 每 5 分钟执行一次

# 配置
CONTAINER_NAME="dnsapi"
SERVICE_URL="http://localhost:5074/api/health"
LOG_FILE="/var/log/dnsapi-monitor.log"
ALERT_FILE="/var/log/dnsapi-alerts.log"
MAX_LOG_SIZE=10485760  # 10MB

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 写日志函数
log() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo -e "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
    
    # 检查日志文件大小，超过限制则轮转
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
        if [ $size -gt $MAX_LOG_SIZE ]; then
            mv "$LOG_FILE" "$LOG_FILE.old"
            echo "[$timestamp] [INFO] 日志文件已轮转" > "$LOG_FILE"
        fi
    fi
}

# 发送告警
send_alert() {
    local subject="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    cat >> "$ALERT_FILE" << EOF

========================================
告警时间: $timestamp
========================================
主题: $subject

详细信息:
$message

容器: $CONTAINER_NAME
服务: $SERVICE_URL
========================================

EOF
    
    log "WARN" "告警: $subject"
}

# 检查容器是否运行
check_container() {
    local status=$(docker ps --filter "name=$CONTAINER_NAME" --format "{{.Status}}")
    
    if [ -z "$status" ]; then
        log "ERROR" "容器 $CONTAINER_NAME 未运行"
        return 1
    else
        log "INFO" "容器状态: $status"
        return 0
    fi
}

# 检查服务健康状态
check_service_health() {
    local response=$(curl -s --max-time 10 "$SERVICE_URL" 2>/dev/null)
    
    if [ -z "$response" ]; then
        log "ERROR" "服务无响应"
        return 1
    fi
    
    local status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    
    if [ "$status" = "healthy" ]; then
        log "INFO" "服务健康检查通过: $status"
        return 0
    else
        log "ERROR" "服务状态异常: $status"
        return 1
    fi
}

# 检查重启策略
check_restart_policy() {
    local policy=$(docker inspect "$CONTAINER_NAME" --format='{{.HostConfig.RestartPolicy.Name}}' 2>/dev/null)
    
    if [ "$policy" != "unless-stopped" ] && [ "$policy" != "always" ]; then
        log "WARN" "重启策略不是自动重启: $policy"
        return 1
    else
        log "INFO" "重启策略: $policy"
        return 0
    fi
}

# 自动修复
auto_fix() {
    log "INFO" "开始自动修复..."
    
    local fixed=0
    
    # 检查容器是否需要启动
    if ! check_container; then
        log "INFO" "正在启动容器..."
        docker start "$CONTAINER_NAME"
        
        sleep 5
        
        if check_container; then
            log "SUCCESS" "容器启动成功"
            fixed=1
        else
            log "ERROR" "容器启动失败"
            send_alert "容器启动失败" "容器 $CONTAINER_NAME 无法启动，需要人工检查"
            return 1
        fi
    fi
    
    # 检查并修复重启策略
    if ! check_restart_policy; then
        log "INFO" "设置自动重启策略..."
        docker update --restart=unless-stopped "$CONTAINER_NAME"
        log "SUCCESS" "已设置重启策略为 unless-stopped"
        fixed=1
    fi
    
    # 如果进行了修复，等待服务启动并验证
    if [ $fixed -eq 1 ]; then
        log "INFO" "等待服务启动..."
        sleep 5
        
        if check_service_health; then
            log "SUCCESS" "自动修复成功，服务已恢复"
            send_alert "服务已自动修复" "容器已重新启动，服务恢复正常"
            return 0
        else
            log "ERROR" "服务仍未响应"
            send_alert "自动修复失败" "容器已启动但服务仍无响应，需要人工检查"
            return 1
        fi
    fi
    
    return 0
}

# 主检查流程
main() {
    log "INFO" "========== 开始健康检查 =========="
    
    local has_error=0
    local needs_fix=0
    
    # 1. 检查容器状态
    if ! check_container; then
        has_error=1
        needs_fix=1
    fi
    
    # 2. 检查服务健康状态
    if ! check_service_health; then
        has_error=1
        needs_fix=1
    fi
    
    # 3. 检查重启策略
    if ! check_restart_policy; then
        needs_fix=1
    fi
    
    # 4. 如果发现问题，尝试自动修复
    if [ $needs_fix -eq 1 ]; then
        auto_fix
        has_error=$?
    fi
    
    # 5. 检查系统资源
    log "INFO" "检查系统资源..."
    local mem_usage=$(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}')
    log "INFO" "内存使用: $mem_usage, 磁盘使用: $disk_usage"
    
    # 如果内存或磁盘使用过高，记录告警
    local mem_percent=$(echo $mem_usage | sed 's/%//')
    local disk_percent=$(echo $disk_usage | sed 's/%//')
    
    if [ $(echo "$mem_percent > 90" | bc) -eq 1 ]; then
        log "WARN" "内存使用率过高: $mem_usage"
        send_alert "内存使用率过高" "当前内存使用率: $mem_usage"
    fi
    
    if [ $(echo "$disk_percent > 85" | bc) -eq 1 ]; then
        log "WARN" "磁盘使用率过高: $disk_usage"
        send_alert "磁盘使用率过高" "当前磁盘使用率: $disk_usage"
    fi
    
    log "INFO" "========== 健康检查完成 =========="
    
    return $has_error
}

# 执行主函数
main
exit $?
