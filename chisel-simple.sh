#!/bin/bash

# Chisel 一键客户端脚本
# 版本: 2.0
# 描述: 一个脚本完成所有操作 - 下载、安装、配置、启动 chisel 客户端
# 使用: ./chisel-simple.sh [服务器地址] [认证信息] [隧道配置]

set -eo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
CHISEL_VERSION="v1.10.1"
DEFAULT_SERVER="http://localhost:8080"
DEFAULT_TUNNELS="socks"

# 路径配置
if [[ $EUID -eq 0 ]] || [[ -w /usr/local/bin ]] 2>/dev/null; then
    # 系统级安装
    INSTALL_DIR="/usr/local/bin"
    CONFIG_DIR="/etc/chisel"
    LOG_DIR="/var/log/chisel"
    PID_FILE="/var/run/chisel-client.pid"
    USE_SUDO=""
else
    # 用户级安装
    INSTALL_DIR="$HOME/.local/bin"
    CONFIG_DIR="$HOME/.config/chisel"
    LOG_DIR="$HOME/.local/share/chisel/logs"
    PID_FILE="$HOME/.local/share/chisel/chisel-client.pid"
    USE_SUDO=""
fi

# 日志函数
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << 'EOF'
Chisel 一键客户端脚本

用法:
    ./chisel-simple.sh [命令] [选项]

命令:
    start [服务器] [认证] [隧道]  启动客户端
    stop                        停止客户端
    status                      查看状态
    logs                        查看日志
    install                     仅安装 chisel
    config                      配置向导
    help                        显示帮助

快速启动示例:
    ./chisel-simple.sh start http://server:8080 user:pass socks
    ./chisel-simple.sh start http://server:8080 user:pass "3000:localhost:3000"
    ./chisel-simple.sh start http://server:8080 "" "socks 8080:google.com:80"

配置文件示例:
    ./chisel-simple.sh config

管理命令:
    ./chisel-simple.sh status
    ./chisel-simple.sh stop
    ./chisel-simple.sh logs

注意: 首次运行会自动下载和安装 chisel
EOF
}

# 检测系统架构
detect_arch() {
    case $(uname -m) in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv7" ;;
        *) error "不支持的架构: $(uname -m)"; exit 1 ;;
    esac
}

# 下载并安装 chisel
install_chisel() {
    if command -v chisel >/dev/null 2>&1; then
        log "chisel 已安装，跳过下载"
        return 0
    fi

    log "下载 chisel ${CHISEL_VERSION}..."
    
    local arch=$(detect_arch)
    local url="https://github.com/jpillora/chisel/releases/download/${CHISEL_VERSION}/chisel_${CHISEL_VERSION#v}_linux_${arch}.gz"
    
    # 创建目录
    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$(dirname "$PID_FILE")"
    
    # 下载到临时目录
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    if command -v wget >/dev/null 2>&1; then
        wget -q "$url" -O chisel.gz
    elif command -v curl >/dev/null 2>&1; then
        curl -sL "$url" -o chisel.gz
    else
        error "需要 wget 或 curl 工具"
        exit 1
    fi
    
    # 解压安装
    gunzip chisel.gz
    chmod +x chisel
    
    if [[ "$INSTALL_DIR" == "/usr/local/bin" ]] && [[ $EUID -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
            sudo mv chisel "$INSTALL_DIR/"
        else
            warn "无 sudo 权限，改为用户级安装"
            INSTALL_DIR="$HOME/.local/bin"
            mkdir -p "$INSTALL_DIR"
            mv chisel "$INSTALL_DIR/"
        fi
    else
        mv chisel "$INSTALL_DIR/"
    fi
    
    # 清理
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    # 配置 PATH
    if [[ "$INSTALL_DIR" == "$HOME/.local/bin" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        export PATH="$HOME/.local/bin:$PATH"
        if [[ -f "$HOME/.bashrc" ]] && ! grep -q "HOME/.local/bin" "$HOME/.bashrc"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            warn "已添加 PATH 配置到 ~/.bashrc，请重新登录或运行: source ~/.bashrc"
        fi
    fi
    
    log "chisel 安装完成: $INSTALL_DIR/chisel"
}

# 获取进程 PID
get_pid() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
        else
            rm -f "$PID_FILE"
        fi
    fi
}

# 检查是否运行
is_running() {
    [[ -n "$(get_pid)" ]]
}

# 启动客户端
start_client() {
    local server="${1:-$DEFAULT_SERVER}"
    local auth="${2:-}"
    local tunnels="${3:-$DEFAULT_TUNNELS}"
    
    if is_running; then
        warn "客户端已在运行 (PID: $(get_pid))"
        return 0
    fi
    
    # 确保 chisel 已安装
    install_chisel
    
    log "启动 chisel 客户端..."
    log "服务器: $server"
    log "隧道: $tunnels"
    
    # 构建命令
    local cmd="chisel client"
    
    # 添加认证
    if [[ -n "$auth" ]]; then
        cmd="$cmd --auth '$auth'"
    fi
    
    # 添加服务器和隧道
    cmd="$cmd '$server' $tunnels"
    
    # 启动并记录 PID
    log "执行: $cmd"
    nohup bash -c "$cmd" > "$LOG_DIR/client.log" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    # 等待启动
    sleep 2
    
    if is_running; then
        log "客户端启动成功 (PID: $pid)"
        log "日志文件: $LOG_DIR/client.log"
        
        # 显示连接信息
        if [[ "$tunnels" == *"socks"* ]]; then
            log "SOCKS5 代理: 127.0.0.1:1080"
        fi
    else
        error "客户端启动失败，请查看日志: $LOG_DIR/client.log"
        return 1
    fi
}

# 停止客户端
stop_client() {
    if ! is_running; then
        warn "客户端未运行"
        return 0
    fi
    
    local pid=$(get_pid)
    log "停止客户端 (PID: $pid)..."
    
    kill -TERM "$pid" 2>/dev/null || true
    
    # 等待进程结束
    local count=0
    while is_running && [[ $count -lt 10 ]]; do
        sleep 1
        ((count++))
    done
    
    if is_running; then
        warn "强制停止..."
        kill -KILL "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    rm -f "$PID_FILE"
    
    if is_running; then
        error "停止失败"
        return 1
    else
        log "客户端已停止"
    fi
}

# 显示状态
show_status() {
    echo "=== Chisel 客户端状态 ==="
    echo "安装路径: $INSTALL_DIR/chisel"
    echo "配置目录: $CONFIG_DIR"
    echo "日志文件: $LOG_DIR/client.log"
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
            echo "本地监听端口:"
            netstat -tlnp 2>/dev/null | grep -E ":(1080|3000|8080)" | head -5 || echo "无相关端口监听"
        fi
    else
        echo -e "状态: ${RED}未运行${NC}"
    fi
}

# 查看日志
show_logs() {
    local log_file="$LOG_DIR/client.log"
    if [[ -f "$log_file" ]]; then
        echo "=== 最近 20 行日志 ==="
        tail -20 "$log_file"
        echo
        echo "实时日志 (Ctrl+C 退出):"
        tail -f "$log_file"
    else
        warn "日志文件不存在: $log_file"
    fi
}

# 配置向导
config_wizard() {
    echo "=== Chisel 配置向导 ==="
    echo
    
    # 服务器地址
    read -p "服务器地址 (默认: $DEFAULT_SERVER): " server
    server=${server:-$DEFAULT_SERVER}
    
    # 认证信息
    read -p "认证信息 (格式: username:password，留空跳过): " auth
    
    # 隧道类型选择
    echo
    echo "隧道类型选择:"
    echo "1) SOCKS5 代理 (推荐)"
    echo "2) 端口转发"
    echo "3) 自定义"
    read -p "请选择 (1-3): " choice
    
    case $choice in
        1)
            tunnels="socks"
            echo "将创建 SOCKS5 代理，监听 127.0.0.1:1080"
            ;;
        2)
            read -p "本地端口: " local_port
            read -p "远程主机: " remote_host
            read -p "远程端口: " remote_port
            tunnels="${local_port}:${remote_host}:${remote_port}"
            ;;
        3)
            read -p "隧道配置: " tunnels
            ;;
        *)
            tunnels="socks"
            ;;
    esac
    
    echo
    echo "配置完成！启动命令:"
    echo "./chisel-simple.sh start '$server' '$auth' '$tunnels'"
    echo
    read -p "是否立即启动? (y/N): " start_now
    
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        start_client "$server" "$auth" "$tunnels"
    fi
}

# 主函数
main() {
    local command="${1:-help}"
    
    case $command in
        start)
            start_client "$2" "$3" "$4"
            ;;
        stop)
            stop_client
            ;;
        restart)
            stop_client
            sleep 1
            start_client "$2" "$3" "$4"
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        install)
            install_chisel
            ;;
        config)
            config_wizard
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知命令: $command"
            echo "运行 './chisel-simple.sh help' 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
