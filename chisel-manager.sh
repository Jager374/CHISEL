#!/bin/bash

# Chisel 集群管理工具
# 版本: 1.0
# 描述: 统一管理多个 chisel 客户端和服务端实例

set -euo pipefail

# 脚本信息
SCRIPT_NAME="chisel-manager"
SCRIPT_VERSION="1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 默认路径
if [[ $EUID -eq 0 ]]; then
    CONFIG_DIR="/etc/chisel"
    LOG_DIR="/var/log/chisel"
    SCRIPT_DIR="/opt/chisel"
else
    CONFIG_DIR="$HOME/.config/chisel"
    LOG_DIR="$HOME/.local/share/chisel/logs"
    SCRIPT_DIR="$HOME/.local/share/chisel"
fi

# 如果在当前目录找到脚本文件，优先使用当前目录
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$CURRENT_DIR/chisel-server.sh" && -f "$CURRENT_DIR/chisel-client.sh" ]]; then
    SCRIPT_DIR="$CURRENT_DIR"
    CONFIG_DIR="$CURRENT_DIR"
    LOG_DIR="$CURRENT_DIR/logs"
fi

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') $1"
}

# 检查脚本是否存在
check_scripts() {
    local missing=()
    
    if [[ ! -f "$SCRIPT_DIR/chisel-server.sh" ]]; then
        missing+=("chisel-server.sh")
    fi
    
    if [[ ! -f "$SCRIPT_DIR/chisel-client.sh" ]]; then
        missing+=("chisel-client.sh")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少脚本文件: ${missing[*]}"
        log_error "请确保已正确安装 chisel 管理脚本"
        exit 1
    fi
}

# 获取服务状态
get_service_status() {
    local service_type="$1"
    local script_path="$SCRIPT_DIR/chisel-${service_type}.sh"
    
    if [[ -f "$script_path" ]]; then
        if bash "$script_path" status >/dev/null 2>&1; then
            echo "running"
        else
            echo "stopped"
        fi
    else
        echo "missing"
    fi
}

# 显示服务状态
show_service_status() {
    local service_type="$1"
    local status=$(get_service_status "$service_type")
    
    case $status in
        running)
            echo -e "${GREEN}运行中${NC}"
            ;;
        stopped)
            echo -e "${RED}已停止${NC}"
            ;;
        missing)
            echo -e "${YELLOW}未安装${NC}"
            ;;
        *)
            echo -e "${YELLOW}未知${NC}"
            ;;
    esac
}

# 显示整体状态
show_status() {
    echo "=== Chisel 集群状态 ==="
    echo
    
    # 服务端状态
    echo -n "服务端: "
    show_service_status "server"
    
    # 客户端状态
    echo -n "客户端: "
    show_service_status "client"
    
    echo
    
    # 详细信息
    if [[ $(get_service_status "server") == "running" ]]; then
        echo "=== 服务端详细信息 ==="
        bash "$SCRIPT_DIR/chisel-server.sh" status 2>/dev/null || true
        echo
    fi
    
    if [[ $(get_service_status "client") == "running" ]]; then
        echo "=== 客户端详细信息 ==="
        bash "$SCRIPT_DIR/chisel-client.sh" status 2>/dev/null || true
        echo
    fi
    
    # 系统资源使用情况
    show_system_info
}

# 显示系统信息
show_system_info() {
    echo "=== 系统资源使用情况 ==="
    
    # CPU 和内存使用情况
    if command -v free >/dev/null 2>&1; then
        echo "内存使用:"
        free -h | head -2
        echo
    fi
    
    # 磁盘使用情况
    if command -v df >/dev/null 2>&1; then
        echo "磁盘使用:"
        df -h / | tail -1
        echo
    fi
    
    # 网络连接
    if command -v netstat >/dev/null 2>&1; then
        echo "网络连接:"
        netstat -tlnp 2>/dev/null | grep -E ":(8080|1080|3128)" || echo "无相关端口监听"
        echo
    fi
}

# 启动所有服务
start_all() {
    log_info "启动所有 chisel 服务..."
    
    # 启动服务端
    if [[ -f "$CONFIG_DIR/chisel-server.conf" ]]; then
        log_info "启动服务端..."
        bash "$SCRIPT_DIR/chisel-server.sh" start
    else
        log_warn "服务端配置文件不存在，跳过启动"
    fi
    
    # 启动客户端
    if [[ -f "$CONFIG_DIR/chisel-client.conf" ]]; then
        log_info "启动客户端..."
        bash "$SCRIPT_DIR/chisel-client.sh" start
    else
        log_warn "客户端配置文件不存在，跳过启动"
    fi
    
    log_info "所有服务启动完成"
}

# 停止所有服务
stop_all() {
    log_info "停止所有 chisel 服务..."
    
    # 停止客户端
    if [[ $(get_service_status "client") == "running" ]]; then
        log_info "停止客户端..."
        bash "$SCRIPT_DIR/chisel-client.sh" stop
    fi
    
    # 停止服务端
    if [[ $(get_service_status "server") == "running" ]]; then
        log_info "停止服务端..."
        bash "$SCRIPT_DIR/chisel-server.sh" stop
    fi
    
    log_info "所有服务已停止"
}

# 重启所有服务
restart_all() {
    log_info "重启所有 chisel 服务..."
    stop_all
    sleep 2
    start_all
}

# 查看日志
show_logs() {
    local service_type="${1:-all}"
    
    case $service_type in
        server)
            if [[ -f "$LOG_DIR/server.log" ]]; then
                tail -f "$LOG_DIR/server.log"
            else
                log_error "服务端日志文件不存在"
            fi
            ;;
        client)
            if [[ -f "$LOG_DIR/client.log" ]]; then
                tail -f "$LOG_DIR/client.log"
            else
                log_error "客户端日志文件不存在"
            fi
            ;;
        all|*)
            if [[ -f "$LOG_DIR/server.log" && -f "$LOG_DIR/client.log" ]]; then
                tail -f "$LOG_DIR/server.log" "$LOG_DIR/client.log"
            elif [[ -f "$LOG_DIR/server.log" ]]; then
                tail -f "$LOG_DIR/server.log"
            elif [[ -f "$LOG_DIR/client.log" ]]; then
                tail -f "$LOG_DIR/client.log"
            else
                log_error "没有找到日志文件"
            fi
            ;;
    esac
}

# 配置管理
manage_config() {
    local action="$1"
    local service_type="${2:-}"
    
    case $action in
        list)
            echo "=== 配置文件列表 ==="
            for config in "$CONFIG_DIR"/*.conf; do
                if [[ -f "$config" ]]; then
                    echo "$(basename "$config"): $(wc -l < "$config") 行"
                fi
            done
            ;;
        edit)
            if [[ -z "$service_type" ]]; then
                log_error "请指定要编辑的服务类型 (server|client)"
                exit 1
            fi
            
            local config_file="$CONFIG_DIR/chisel-${service_type}.conf"
            if [[ -f "$config_file" ]]; then
                ${EDITOR:-nano} "$config_file"
            else
                log_error "配置文件不存在: $config_file"
            fi
            ;;
        backup)
            local backup_dir="$CONFIG_DIR/backup"
            local timestamp=$(date '+%Y%m%d_%H%M%S')
            
            mkdir -p "$backup_dir"
            
            for config in "$CONFIG_DIR"/*.conf; do
                if [[ -f "$config" ]]; then
                    cp "$config" "$backup_dir/$(basename "$config").${timestamp}"
                    log_info "已备份: $(basename "$config")"
                fi
            done
            ;;
        restore)
            local backup_dir="$CONFIG_DIR/backup"
            if [[ ! -d "$backup_dir" ]]; then
                log_error "备份目录不存在: $backup_dir"
                exit 1
            fi
            
            echo "可用的备份文件:"
            ls -la "$backup_dir"
            ;;
        *)
            log_error "未知的配置操作: $action"
            exit 1
            ;;
    esac
}

# 健康检查
health_check() {
    local issues=()

    echo "=== 健康检查 ==="

    # 检查 chisel 是否安装
    if ! command -v chisel >/dev/null 2>&1; then
        # 检查用户级安装
        if [[ -f "$HOME/.local/bin/chisel" ]]; then
            echo -e "${GREEN}✓${NC} chisel 已安装 (用户级)"
            if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
                echo -e "${YELLOW}!${NC} $HOME/.local/bin 不在 PATH 中"
                issues+=("PATH 配置问题")
            fi
        else
            issues+=("chisel 未安装")
        fi
    else
        echo -e "${GREEN}✓${NC} chisel 已安装"
    fi
    
    # 检查配置文件
    for config in server client; do
        if [[ -f "$CONFIG_DIR/chisel-${config}.conf" ]]; then
            echo -e "${GREEN}✓${NC} ${config} 配置文件存在"
        else
            issues+=("${config} 配置文件缺失")
        fi
    done
    
    # 检查日志目录
    if [[ -d "$LOG_DIR" ]]; then
        echo -e "${GREEN}✓${NC} 日志目录存在"
    else
        issues+=("日志目录不存在")
    fi
    
    # 检查服务状态
    for service in server client; do
        local status=$(get_service_status "$service")
        if [[ "$status" == "running" ]]; then
            echo -e "${GREEN}✓${NC} ${service} 服务运行正常"
        elif [[ "$status" == "stopped" ]]; then
            echo -e "${YELLOW}!${NC} ${service} 服务已停止"
        else
            issues+=("${service} 服务状态异常")
        fi
    done
    
    # 检查端口占用
    if command -v netstat >/dev/null 2>&1; then
        local ports=("8080" "1080")
        for port in "${ports[@]}"; do
            if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
                echo -e "${GREEN}✓${NC} 端口 ${port} 正在监听"
            else
                echo -e "${YELLOW}!${NC} 端口 ${port} 未监听"
            fi
        done
    fi
    
    echo
    
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo -e "${GREEN}健康检查通过，系统运行正常${NC}"
        return 0
    else
        echo -e "${RED}发现以下问题:${NC}"
        for issue in "${issues[@]}"; do
            echo -e "  ${RED}✗${NC} $issue"
        done
        return 1
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [命令] [选项]

命令:
    status              显示所有服务状态
    start               启动所有服务
    stop                停止所有服务
    restart             重启所有服务
    logs [service]      查看日志 (service: server|client|all)
    health              执行健康检查
    config <action>     配置管理
        list            列出所有配置文件
        edit <service>  编辑配置文件 (service: server|client)
        backup          备份配置文件
        restore         恢复配置文件
    help                显示帮助信息

示例:
    $0 status           # 查看状态
    $0 start            # 启动所有服务
    $0 logs client      # 查看客户端日志
    $0 config edit server  # 编辑服务端配置
    $0 health           # 执行健康检查

版本: $SCRIPT_VERSION
EOF
}

# 主函数
main() {
    local command="${1:-status}"
    
    # 检查脚本文件
    check_scripts
    
    case $command in
        status)
            show_status
            ;;
        start)
            start_all
            ;;
        stop)
            stop_all
            ;;
        restart)
            restart_all
            ;;
        logs)
            show_logs "${2:-all}"
            ;;
        health)
            health_check
            ;;
        config)
            if [[ $# -lt 2 ]]; then
                log_error "config 命令需要指定操作"
                show_help
                exit 1
            fi
            manage_config "${2}" "${3:-}"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
