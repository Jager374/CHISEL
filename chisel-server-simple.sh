#!/bin/bash

# Chisel 一键服务端脚本
# 版本: 2.0
# 描述: 一个脚本完成所有操作 - 下载、安装、配置、启动 chisel 服务端

set -eo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 默认配置
CHISEL_VERSION="v1.10.1"
DEFAULT_PORT="8080"
DEFAULT_HOST="0.0.0.0"

# 路径配置
if [[ $EUID -eq 0 ]] || [[ -w /usr/local/bin ]] 2>/dev/null; then
    INSTALL_DIR="/usr/local/bin"
    CONFIG_DIR="/etc/chisel"
    LOG_DIR="/var/log/chisel"
    PID_FILE="/var/run/chisel-server.pid"
else
    INSTALL_DIR="$HOME/.local/bin"
    CONFIG_DIR="$HOME/.config/chisel"
    LOG_DIR="$HOME/.local/share/chisel/logs"
    PID_FILE="$HOME/.local/share/chisel/chisel-server.pid"
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
Chisel 一键服务端脚本

用法:
    ./chisel-server-simple.sh [命令] [选项]

命令:
    start [端口] [认证]         启动服务端
    stop                       停止服务端
    status                     查看状态
    logs                       查看日志
    install                    仅安装 chisel
    users                      用户管理
    help                       显示帮助

快速启动示例:
    ./chisel-server-simple.sh start                    # 默认端口 8080
    ./chisel-server-simple.sh start 9000               # 指定端口
    ./chisel-server-simple.sh start 8080 admin:123456  # 带认证

用户管理:
    ./chisel-server-simple.sh users add user1:pass123
    ./chisel-server-simple.sh users list
    ./chisel-server-simple.sh users remove user1

管理命令:
    ./chisel-server-simple.sh status
    ./chisel-server-simple.sh stop
    ./chisel-server-simple.sh logs

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

# 生成用户文件
create_users_file() {
    local users_file="$CONFIG_DIR/users.json"
    if [[ ! -f "$users_file" ]]; then
        cat > "$users_file" << 'EOF'
{
  "admin:admin123": [".*"],
  "user:password": [".*:.*", "R:.*:.*"]
}
EOF
        log "已创建默认用户文件: $users_file"
        log "默认用户: admin:admin123 (完全权限)"
        log "默认用户: user:password (标准权限)"
    fi
}

# 启动服务端
start_server() {
    local port="${1:-$DEFAULT_PORT}"
    local auth="${2:-}"
    
    if is_running; then
        warn "服务端已在运行 (PID: $(get_pid))"
        return 0
    fi
    
    # 确保 chisel 已安装
    install_chisel
    
    log "启动 chisel 服务端..."
    log "监听端口: $port"
    
    # 构建命令
    local cmd="chisel server --host $DEFAULT_HOST --port $port --socks5 --reverse"
    
    # 添加认证
    if [[ -n "$auth" ]]; then
        cmd="$cmd --auth '$auth'"
        log "认证: $auth"
    else
        # 使用用户文件认证
        create_users_file
        cmd="$cmd --authfile '$CONFIG_DIR/users.json'"
        log "使用用户文件认证: $CONFIG_DIR/users.json"
    fi
    
    # 启动并记录 PID
    log "执行: $cmd"
    nohup bash -c "$cmd" > "$LOG_DIR/server.log" 2>&1 &
    local pid=$!
    echo $pid > "$PID_FILE"
    
    # 等待启动
    sleep 2
    
    if is_running; then
        log "服务端启动成功 (PID: $pid)"
        log "监听地址: $DEFAULT_HOST:$port"
        log "日志文件: $LOG_DIR/server.log"
        log "功能: SOCKS5 代理 + 反向隧道"
        
        # 显示连接信息
        echo
        log "客户端连接示例:"
        if [[ -n "$auth" ]]; then
            echo "  ./chisel-simple.sh start http://$(hostname -I | awk '{print $1}'):$port '$auth' socks"
        else
            echo "  ./chisel-simple.sh start http://$(hostname -I | awk '{print $1}'):$port 'admin:admin123' socks"
        fi
    else
        error "服务端启动失败，请查看日志: $LOG_DIR/server.log"
        return 1
    fi
}

# 停止服务端
stop_server() {
    if ! is_running; then
        warn "服务端未运行"
        return 0
    fi
    
    local pid=$(get_pid)
    log "停止服务端 (PID: $pid)..."
    
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
        log "服务端已停止"
    fi
}

# 显示状态
show_status() {
    echo "=== Chisel 服务端状态 ==="
    echo "安装路径: $INSTALL_DIR/chisel"
    echo "配置目录: $CONFIG_DIR"
    echo "日志文件: $LOG_DIR/server.log"
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
            netstat -tlnp 2>/dev/null | grep ":$DEFAULT_PORT\|:8080\|:9000" || echo "无相关端口监听"
        fi
    else
        echo -e "状态: ${RED}未运行${NC}"
    fi
}

# 查看日志
show_logs() {
    local log_file="$LOG_DIR/server.log"
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

# 用户管理
manage_users() {
    local action="$1"
    local user_info="$2"
    local users_file="$CONFIG_DIR/users.json"
    
    case $action in
        add)
            if [[ -z "$user_info" ]]; then
                error "请提供用户信息，格式: username:password"
                return 1
            fi
            
            create_users_file
            
            # 简单添加用户（实际应该用 jq，这里用简单方法）
            local username=$(echo "$user_info" | cut -d: -f1)
            log "添加用户: $username"
            warn "请手动编辑 $users_file 添加用户权限"
            ;;
        list)
            if [[ -f "$users_file" ]]; then
                echo "=== 用户列表 ==="
                grep -o '"[^"]*:' "$users_file" | sed 's/[":]*//g' | sort
            else
                warn "用户文件不存在: $users_file"
            fi
            ;;
        remove)
            warn "请手动编辑 $users_file 删除用户"
            ;;
        *)
            echo "用户管理命令:"
            echo "  add username:password  - 添加用户"
            echo "  list                   - 列出用户"
            echo "  remove username        - 删除用户"
            ;;
    esac
}

# 主函数
main() {
    local command="${1:-help}"
    
    case $command in
        start)
            start_server "$2" "$3"
            ;;
        stop)
            stop_server
            ;;
        restart)
            stop_server
            sleep 1
            start_server "$2" "$3"
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
        users)
            manage_users "$2" "$3"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo "未知命令: $command"
            echo "运行 './chisel-server-simple.sh help' 查看帮助"
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
