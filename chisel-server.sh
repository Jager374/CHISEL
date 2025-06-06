#!/bin/bash

# Chisel 服务端启动脚本
# 版本: 1.0
# 描述: 管理 chisel 服务端的启动、停止、重启和状态查看

set -euo pipefail

# 脚本信息
SCRIPT_NAME="chisel-server"
SCRIPT_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置路径
if [[ $EUID -eq 0 ]]; then
    DEFAULT_CONFIG="/etc/chisel/chisel-server.conf"
    DEFAULT_LOG_DIR="/var/log/chisel"
    DEFAULT_PID_DIR="/var/run"
else
    DEFAULT_CONFIG="$HOME/.config/chisel/chisel-server.conf"
    DEFAULT_LOG_DIR="$HOME/.local/share/chisel/logs"
    DEFAULT_PID_DIR="$HOME/.local/share/chisel"
fi

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
    SERVER_HOST="${SERVER_HOST:-0.0.0.0}"
    SERVER_PORT="${SERVER_PORT:-8080}"
    ENABLE_SOCKS5="${ENABLE_SOCKS5:-true}"
    ENABLE_REVERSE="${ENABLE_REVERSE:-true}"
    KEEPALIVE="${KEEPALIVE:-25s}"
    VERBOSE="${VERBOSE:-false}"
    LOG_FILE="${LOG_FILE:-$DEFAULT_LOG_DIR/server.log}"
    PID_FILE="${PID_FILE:-$DEFAULT_PID_DIR/chisel-server.pid}"
    ENABLE_PID="${ENABLE_PID:-true}"
    
    # 创建必要的目录
    mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"
}

# 创建默认配置文件
create_default_config() {
    local config_dir="$(dirname "$CONFIG_FILE")"
    mkdir -p "$config_dir"
    
    cat > "$CONFIG_FILE" << 'EOF'
# Chisel 服务端配置文件
SERVER_HOST="0.0.0.0"
SERVER_PORT="8080"
ENABLE_SOCKS5="true"
ENABLE_REVERSE="true"
KEEPALIVE="25s"
VERBOSE="false"
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

# 生成 SSH 密钥
generate_key() {
    local key_file="${KEY_FILE:-$(dirname "$CONFIG_FILE")/server.key}"
    local key_dir="$(dirname "$key_file")"
    
    mkdir -p "$key_dir"
    
    if [[ ! -f "$key_file" ]]; then
        log_info "生成 SSH 密钥: $key_file"
        chisel server --keygen "$key_file" >/dev/null 2>&1
        chmod 600 "$key_file"
        log_info "SSH 密钥已生成"
    fi
    
    echo "$key_file"
}

# 构建命令行参数
build_args() {
    local args=()
    
    # 基础参数
    args+=("server")
    args+=("--host" "$SERVER_HOST")
    args+=("--port" "$SERVER_PORT")
    args+=("--keepalive" "$KEEPALIVE")
    
    # SSH 密钥
    if [[ -n "${KEY_FILE:-}" ]]; then
        args+=("--keyfile" "$KEY_FILE")
    else
        local key_file=$(generate_key)
        args+=("--keyfile" "$key_file")
    fi
    
    # 认证配置
    if [[ -n "${AUTH_FILE:-}" && -f "$AUTH_FILE" ]]; then
        args+=("--authfile" "$AUTH_FILE")
    elif [[ -n "${AUTH_USER:-}" ]]; then
        args+=("--auth" "$AUTH_USER")
    fi
    
    # 功能开关
    if [[ "${ENABLE_SOCKS5:-true}" == "true" ]]; then
        args+=("--socks5")
    fi
    
    if [[ "${ENABLE_REVERSE:-true}" == "true" ]]; then
        args+=("--reverse")
    fi
    
    # TLS 配置
    if [[ "${ENABLE_TLS:-false}" == "true" ]]; then
        if [[ -n "${TLS_DOMAIN:-}" ]]; then
            args+=("--tls-domain" "$TLS_DOMAIN")
        elif [[ -n "${TLS_CERT:-}" && -n "${TLS_KEY:-}" ]]; then
            args+=("--tls-cert" "$TLS_CERT")
            args+=("--tls-key" "$TLS_KEY")
        fi
        
        if [[ -n "${TLS_CA:-}" ]]; then
            args+=("--tls-ca" "$TLS_CA")
        fi
    fi
    
    # 后端代理
    if [[ -n "${BACKEND_PROXY:-}" ]]; then
        args+=("--backend" "$BACKEND_PROXY")
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
    
    echo "${args[@]}"
}

# 启动服务
start_server() {
    if is_running; then
        log_warn "服务已在运行 (PID: $(get_pid))"
        return 0
    fi
    
    log_info "启动 chisel 服务端..."
    
    local args=($(build_args))
    log_debug "执行命令: chisel ${args[*]}"
    
    # 启动服务并重定向输出到日志文件
    nohup chisel "${args[@]}" >> "$LOG_FILE" 2>&1 &
    local pid=$!
    
    # 保存 PID
    if [[ "${ENABLE_PID:-true}" == "true" ]]; then
        echo $pid > "$PID_FILE"
    fi
    
    # 等待服务启动
    sleep 2
    
    if is_running; then
        log_info "服务启动成功 (PID: $pid)"
        show_server_info
    else
        log_error "服务启动失败"
        return 1
    fi
}

# 停止服务
stop_server() {
    if ! is_running; then
        log_warn "服务未运行"
        return 0
    fi
    
    local pid=$(get_pid)
    log_info "停止 chisel 服务端 (PID: $pid)..."
    
    # 发送 TERM 信号
    kill -TERM "$pid" 2>/dev/null || true
    
    # 等待进程结束
    local count=0
    while is_running && [[ $count -lt 30 ]]; do
        sleep 1
        ((count++))
    done
    
    # 如果进程仍在运行，强制杀死
    if is_running; then
        log_warn "强制停止服务..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    # 清理 PID 文件
    if [[ -f "$PID_FILE" ]]; then
        rm -f "$PID_FILE"
    fi
    
    if is_running; then
        log_error "服务停止失败"
        return 1
    else
        log_info "服务已停止"
    fi
}

# 重启服务
restart_server() {
    log_info "重启 chisel 服务端..."
    stop_server
    sleep 2
    start_server
}

# 检查服务是否运行
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
        pgrep -f "chisel server" | head -1 || echo ""
    fi
}

# 显示服务状态
show_status() {
    echo "=== Chisel 服务端状态 ==="
    echo "配置文件: $CONFIG_FILE"
    echo "日志文件: $LOG_FILE"
    echo "PID 文件: $PID_FILE"
    echo
    
    if is_running; then
        local pid=$(get_pid)
        echo -e "状态: ${GREEN}运行中${NC} (PID: $pid)"
        
        # 显示进程信息
        if command -v ps >/dev/null 2>&1; then
            echo "进程信息:"
            ps -p "$pid" -o pid,ppid,user,start,time,command 2>/dev/null || true
        fi
        
        # 显示网络监听
        if command -v netstat >/dev/null 2>&1; then
            echo
            echo "网络监听:"
            netstat -tlnp 2>/dev/null | grep ":${SERVER_PORT}" || true
        fi
    else
        echo -e "状态: ${RED}未运行${NC}"
    fi
}

# 显示服务器信息
show_server_info() {
    echo
    echo "=== 服务器信息 ==="
    echo "监听地址: ${SERVER_HOST}:${SERVER_PORT}"
    echo "SOCKS5 代理: ${ENABLE_SOCKS5:-false}"
    echo "反向隧道: ${ENABLE_REVERSE:-false}"
    
    # 显示服务器指纹
    if [[ -n "${KEY_FILE:-}" && -f "$KEY_FILE" ]]; then
        echo "服务器指纹:"
        chisel server --keyfile "$KEY_FILE" --help 2>&1 | grep -A1 "Fingerprint" || true
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] <命令>

命令:
    start       启动服务
    stop        停止服务
    restart     重启服务
    status      显示状态
    reload      重新加载配置
    logs        查看日志
    help        显示帮助

选项:
    -c, --config FILE   指定配置文件路径
    -v, --verbose       启用详细输出
    -h, --help          显示帮助信息

示例:
    $0 start                    # 启动服务
    $0 -c /path/to/config start # 使用指定配置启动
    $0 status                   # 查看状态
    $0 logs                     # 查看日志

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

# 重新加载配置
reload_config() {
    log_info "重新加载配置..."
    if is_running; then
        restart_server
    else
        log_info "服务未运行，无需重新加载"
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
            start|stop|restart|status|reload|logs|help)
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
            start_server
            ;;
        stop)
            stop_server
            ;;
        restart)
            restart_server
            ;;
        status)
            show_status
            ;;
        reload)
            reload_config
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
