#!/bin/bash

# Chisel 客户端启动脚本
# 版本: 1.0
# 描述: 管理 chisel 客户端的启动、停止、重启和状态查看，支持自动重连

set -euo pipefail

# 脚本信息
SCRIPT_NAME="chisel-client"
SCRIPT_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 智能路径检测
detect_paths() {
    if [[ $EUID -eq 0 ]]; then
        # root 用户使用系统路径
        DEFAULT_CONFIG="/etc/chisel/chisel-client.conf"
        DEFAULT_LOG_DIR="/var/log/chisel"
        DEFAULT_PID_DIR="/var/run"
    elif [[ -w /etc/chisel ]] 2>/dev/null || [[ -f /etc/chisel/chisel-client.conf ]]; then
        # 有权限访问系统配置或系统配置存在
        DEFAULT_CONFIG="/etc/chisel/chisel-client.conf"
        DEFAULT_LOG_DIR="/var/log/chisel"
        DEFAULT_PID_DIR="/var/run"
    else
        # 使用用户级路径
        DEFAULT_CONFIG="$HOME/.config/chisel/chisel-client.conf"
        DEFAULT_LOG_DIR="$HOME/.local/share/chisel/logs"
        DEFAULT_PID_DIR="$HOME/.local/share/chisel"
    fi
}

# 调用路径检测
detect_paths

# 配置文件路径
CONFIG_FILE="${CONFIG_FILE:-$DEFAULT_CONFIG}"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
}

log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$LOG_FILE"
    fi
}

# 加载配置文件
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_debug "加载配置文件: $CONFIG_FILE"
        source "$CONFIG_FILE"
    else
        log_warn "配置文件不存在: $CONFIG_FILE，使用默认配置"
        create_default_config
    fi
    
    # 设置默认值
    SERVER_URL="${SERVER_URL:-http://localhost:8080}"
    REMOTE_TUNNELS="${REMOTE_TUNNELS:-socks}"
    KEEPALIVE="${KEEPALIVE:-25s}"
    MAX_RETRY_COUNT="${MAX_RETRY_COUNT:-0}"
    MAX_RETRY_INTERVAL="${MAX_RETRY_INTERVAL:-5m}"
    VERBOSE="${VERBOSE:-false}"
    LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_DIR/client.log}"
    PID_FILE="${PID_FILE:-$DEFAULT_PID_DIR/chisel-client.pid}"
    ENABLE_PID="${ENABLE_PID:-true}"
    ENABLE_RECONNECT="${ENABLE_RECONNECT:-true}"
    RECONNECT_INTERVAL="${RECONNECT_INTERVAL:-10}"
    HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-30}"
    
    # 创建必要的目录
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"
}

# 创建默认配置文件
create_default_config() {
    local config_dir="$(dirname "$CONFIG_FILE")"
    mkdir -p "$config_dir"
    
    cat > "$CONFIG_FILE" << 'EOF'
# Chisel 客户端配置文件
SERVER_URL="http://localhost:8080"
REMOTE_TUNNELS="socks"
KEEPALIVE="25s"
MAX_RETRY_COUNT="0"
VERBOSE="false"
ENABLE_RECONNECT="true"
RECONNECT_INTERVAL="10"
EOF
    
    log_info "已创建默认配置文件: $CONFIG_FILE"
}

# 检查 chisel 是否已安装
check_chisel() {
    if ! command -v chisel >/dev/null 2>&1; then
        log_error "chisel 未安装，请先运行安装脚本"
        exit 1
    fi
}

# 构建命令行参数
build_args() {
    local args=()
    
    # 基础参数
    args+=("client")
    
    # 服务器指纹验证
    if [[ -n "${SERVER_FINGERPRINT:-}" ]]; then
        args+=("--fingerprint" "$SERVER_FINGERPRINT")
    fi
    
    # 认证信息
    if [[ -n "${AUTH_CREDENTIALS:-}" ]]; then
        args+=("--auth" "$AUTH_CREDENTIALS")
    fi
    
    # 连接配置
    args+=("--keepalive" "$KEEPALIVE")
    
    if [[ "${MAX_RETRY_COUNT:-0}" != "0" ]]; then
        args+=("--max-retry-count" "$MAX_RETRY_COUNT")
    fi
    
    if [[ -n "${MAX_RETRY_INTERVAL:-}" ]]; then
        args+=("--max-retry-interval" "$MAX_RETRY_INTERVAL")
    fi
    
    # 代理配置
    if [[ -n "${UPSTREAM_PROXY:-}" ]]; then
        args+=("--proxy" "$UPSTREAM_PROXY")
    fi
    
    # 自定义头部
    if [[ -n "${CUSTOM_HEADERS:-}" ]]; then
        IFS=',' read -ra HEADERS <<< "$CUSTOM_HEADERS"
        for header in "${HEADERS[@]}"; do
            args+=("--header" "$header")
        done
    fi
    
    # 主机名配置
    if [[ -n "${CUSTOM_HOSTNAME:-}" ]]; then
        args+=("--hostname" "$CUSTOM_HOSTNAME")
    fi
    
    if [[ -n "${SNI_HOSTNAME:-}" ]]; then
        args+=("--sni" "$SNI_HOSTNAME")
    fi
    
    # TLS 配置
    if [[ -n "${TLS_CA:-}" ]]; then
        args+=("--tls-ca" "$TLS_CA")
    fi
    
    if [[ "${TLS_SKIP_VERIFY:-false}" == "true" ]]; then
        args+=("--tls-skip-verify")
    fi
    
    if [[ -n "${TLS_CERT:-}" && -n "${TLS_KEY:-}" ]]; then
        args+=("--tls-cert" "$TLS_CERT")
        args+=("--tls-key" "$TLS_KEY")
    fi
    
    # PID 文件
    if [[ "${ENABLE_PID:-true}" == "true" ]]; then
        args+=("--pid")
    fi
    
    # 详细日志
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        args+=("-v")
    fi
    
    # 额外参数
    if [[ -n "${EXTRA_ARGS:-}" ]]; then
        eval "args+=($EXTRA_ARGS)"
    fi
    
    # 服务器 URL
    args+=("$SERVER_URL")
    
    # 远程隧道配置
    if [[ -n "${REMOTE_TUNNELS:-}" ]]; then
        IFS=' ' read -ra TUNNELS <<< "$REMOTE_TUNNELS"
        args+=("${TUNNELS[@]}")
    fi
    
    # 反向隧道配置
    if [[ -n "${REVERSE_TUNNELS:-}" ]]; then
        IFS=' ' read -ra REV_TUNNELS <<< "$REVERSE_TUNNELS"
        args+=("${REV_TUNNELS[@]}")
    fi
    
    echo "${args[@]}"
}

# 测试服务器连接
test_connection() {
    local server_host=$(echo "$SERVER_URL" | sed -E 's|^https?://([^:/]+).*|\1|')
    local server_port=$(echo "$SERVER_URL" | sed -E 's|^https?://[^:/]+:?([0-9]+)?.*|\1|')
    
    if [[ -z "$server_port" ]]; then
        if [[ "$SERVER_URL" =~ ^https:// ]]; then
            server_port="443"
        else
            server_port="80"
        fi
    fi
    
    log_debug "测试连接到 $server_host:$server_port"
    
    if command -v nc >/dev/null 2>&1; then
        if nc -z -w5 "$server_host" "$server_port" 2>/dev/null; then
            return 0
        else
            return 1
        fi
    elif command -v telnet >/dev/null 2>&1; then
        if timeout 5 telnet "$server_host" "$server_port" </dev/null >/dev/null 2>&1; then
            return 0
        else
            return 1
        fi
    else
        log_warn "无法测试连接（缺少 nc 或 telnet 工具）"
        return 0
    fi
}

# 启动客户端
start_client() {
    if is_running; then
        log_warn "客户端已在运行 (PID: $(get_pid))"
        return 0
    fi
    
    log_info "启动 chisel 客户端..."
    
    # 测试服务器连接
    if ! test_connection; then
        log_warn "无法连接到服务器 $SERVER_URL，但仍将尝试启动客户端"
    fi
    
    local args=($(build_args))
    log_debug "执行命令: chisel ${args[*]}"
    
    # 启动客户端并重定向输出到日志文件
    if [[ "${ENABLE_RECONNECT:-true}" == "true" ]]; then
        start_with_reconnect "${args[@]}"
    else
        nohup chisel "${args[@]}" >> "$LOG_FILE" 2>&1 &
        local pid=$!
        
        # 保存 PID
        if [[ "${ENABLE_PID:-true}" == "true" ]]; then
            echo $pid > "$PID_FILE"
        fi
        
        log_info "客户端启动成功 (PID: $pid)"
    fi
}

# 带自动重连的启动
start_with_reconnect() {
    local args=("$@")
    
    # 创建重连脚本
    local reconnect_script="$DEFAULT_PID_DIR/chisel-reconnect.sh"
    cat > "$reconnect_script" << EOF
#!/bin/bash
while true; do
    echo "\$(date '+%Y-%m-%d %H:%M:%S') [INFO] 启动 chisel 客户端..." >> "$LOG_FILE"
    chisel "${args[@]}" >> "$LOG_FILE" 2>&1
    exit_code=\$?
    echo "\$(date '+%Y-%m-%d %H:%M:%S') [WARN] chisel 客户端退出 (退出码: \$exit_code)" >> "$LOG_FILE"
    
    if [[ \$exit_code -eq 0 ]]; then
        echo "\$(date '+%Y-%m-%d %H:%M:%S') [INFO] 客户端正常退出" >> "$LOG_FILE"
        break
    fi
    
    echo "\$(date '+%Y-%m-%d %H:%M:%S') [INFO] ${RECONNECT_INTERVAL} 秒后重新连接..." >> "$LOG_FILE"
    sleep ${RECONNECT_INTERVAL}
done
EOF
    
    chmod +x "$reconnect_script"
    
    # 启动重连脚本
    nohup bash "$reconnect_script" &
    local pid=$!
    
    # 保存 PID
    if [[ "${ENABLE_PID:-true}" == "true" ]]; then
        echo $pid > "$PID_FILE"
    fi
    
    log_info "客户端启动成功，已启用自动重连 (PID: $pid)"
}

# 停止客户端
stop_client() {
    if ! is_running; then
        log_warn "客户端未运行"
        return 0
    fi
    
    local pid=$(get_pid)
    log_info "停止 chisel 客户端 (PID: $pid)..."
    
    # 停止重连脚本和 chisel 进程
    pkill -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
    
    # 等待进程结束
    local count=0
    while is_running && [[ $count -lt 30 ]]; do
        sleep 1
        ((count++))
    done
    
    # 如果进程仍在运行，强制杀死
    if is_running; then
        log_warn "强制停止客户端..."
        pkill -9 -P "$pid" 2>/dev/null || true
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    # 清理文件
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
    
    local reconnect_script="$DEFAULT_PID_DIR/chisel-reconnect.sh"
    if [[ -f "$reconnect_script" ]]; then
        rm -f "$reconnect_script"
    fi
    
    if is_running; then
        log_error "客户端停止失败"
        return 1
    else
        log_info "客户端已停止"
    fi
}

# 重启客户端
restart_client() {
    log_info "重启 chisel 客户端..."
    stop_client
    sleep 2
    start_client
}

# 检查客户端是否运行
is_running() {
    local pid=$(get_pid)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 获取进程 PID
get_pid() {
    if [[ -f "$PID_FILE" ]]; then
        cat "$PID_FILE" 2>/dev/null || echo ""
    else
        pgrep -f "chisel client" | head -1 || echo ""
    fi
}

# 显示客户端状态
show_status() {
    echo "=== Chisel 客户端状态 ==="
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo "PID 文件: $PID_FILE"
    echo "服务器: $SERVER_URL"
    echo
    
    if is_running; then
        local pid=$(get_pid)
        echo -e "状态: ${GREEN}运行中${NC} (PID: $pid)"
        
        # 显示进程信息
        if command -v ps >/dev/null 2>&1; then
            echo "进程信息:"
            ps -p "$pid" -o pid,ppid,user,start,time,command 2>/dev/null || true
        fi
        
        # 显示隧道信息
        echo
        echo "隧道配置:"
        echo "  远程隧道: ${REMOTE_TUNNELS:-无}"
        echo "  反向隧道: ${REVERSE_TUNNELS:-无}"
        
        # 测试连接状态
        if test_connection; then
            echo -e "服务器连接: ${GREEN}正常${NC}"
        else
            echo -e "服务器连接: ${RED}异常${NC}"
        fi
    else
        echo -e "状态: ${RED}未运行${NC}"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] <命令>

命令:
    start       启动客户端
    stop        停止客户端
    restart     重启客户端
    status      显示状态
    test        测试服务器连接
    logs        查看日志
    help        显示帮助

选项:
    -c, --config FILE   指定配置文件路径
    -v, --verbose       启用详细输出
    -h, --help          显示帮助信息

示例:
    $0 start                    # 启动客户端
    $0 -c /path/to/config start # 使用指定配置启动
    $0 status                   # 查看状态
    $0 test                     # 测试服务器连接

版本: $SCRIPT_VERSION
EOF
}

# 查看日志
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -f "$LOG_FILE"
    else
        log_error "日志文件不存在: $LOG_FILE"
    fi
}

# 主函数
main() {
    local command=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            start|stop|restart|status|test|logs|help)
                command="$1"
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 检查命令
    if [[ -z "$command" ]]; then
        log_error "请指定命令"
        show_help
        exit 1
    fi
    
    # 加载配置
    load_config
    
    # 检查 chisel
    check_chisel
    
    # 执行命令
    case $command in
        start)
            start_client
            ;;
        stop)
            stop_client
            ;;
        restart)
            restart_client
            ;;
        status)
            show_status
            ;;
        test)
            if test_connection; then
                log_info "服务器连接正常"
            else
                log_error "服务器连接失败"
                exit 1
            fi
            ;;
        logs)
            show_logs
            ;;
        help)
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
