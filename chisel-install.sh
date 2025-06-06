#!/bin/bash

# Chisel 代理服务器集群管理方案 - 安装脚本
# 作者: Augment Agent
# 版本: 1.0
# 描述: 自动安装和配置 chisel 工具及相关脚本

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置变量
CHISEL_VERSION="v1.10.1"
INSTALL_DIR="/opt/chisel"
CONFIG_DIR="/etc/chisel"
LOG_DIR="/var/log/chisel"
SYSTEMD_DIR="/etc/systemd/system"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# 检查是否可以使用 sudo
check_sudo() {
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# 安全执行命令（自动选择是否使用 sudo）
safe_exec() {
    local cmd="$1"
    if check_root; then
        eval "$cmd"
    elif check_sudo; then
        eval "sudo $cmd"
    else
        log_warn "无 sudo 权限，跳过需要管理员权限的操作: $cmd"
        return 1
    fi
}

# 检测系统架构
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l)
            echo "armv7"
            ;;
        *)
            log_error "不支持的系统架构: $arch"
            exit 1
            ;;
    esac
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo $ID
    else
        log_error "无法检测操作系统"
        exit 1
    fi
}

# 下载 chisel 二进制文件
download_chisel() {
    local arch=$(detect_arch)
    local os=$(detect_os)
    local download_url="https://github.com/jpillora/chisel/releases/download/${CHISEL_VERSION}/chisel_${CHISEL_VERSION#v}_linux_${arch}.gz"

    log_info "下载 chisel ${CHISEL_VERSION} for ${os}_${arch}..."

    # 创建临时目录
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"

    # 下载文件
    if command -v wget >/dev/null 2>&1; then
        wget -q "$download_url" -O chisel.gz
    elif command -v curl >/dev/null 2>&1; then
        curl -sL "$download_url" -o chisel.gz
    else
        log_error "需要安装 wget 或 curl"
        exit 1
    fi

    # 解压并安装
    gunzip chisel.gz
    chmod +x chisel

    # 智能选择安装位置
    if check_root; then
        mv chisel /usr/local/bin/
        log_info "chisel 已安装到 /usr/local/bin/"
    elif check_sudo && [[ -w /usr/local/bin ]] || safe_exec "test -w /usr/local/bin"; then
        safe_exec "mv chisel /usr/local/bin/"
        log_info "chisel 已安装到 /usr/local/bin/"
    else
        # 用户级安装
        mkdir -p "$HOME/.local/bin"
        mv chisel "$HOME/.local/bin/"
        log_info "chisel 已安装到 $HOME/.local/bin/"

        # 检查 PATH 配置
        if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
            log_warn "请将 $HOME/.local/bin 添加到您的 PATH 中"
            log_info "可以运行: echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
            log_info "然后运行: source ~/.bashrc"
        fi
    fi

    # 清理临时文件
    cd - >/dev/null
    rm -rf "$temp_dir"
}

# 创建目录结构
create_directories() {
    if check_root; then
        mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"
        chown -R root:root "$INSTALL_DIR" "$CONFIG_DIR"
        chmod 755 "$INSTALL_DIR" "$CONFIG_DIR"
        chmod 755 "$LOG_DIR"
        log_info "已创建系统目录结构"
    elif check_sudo; then
        # 尝试创建系统目录
        if safe_exec "mkdir -p $INSTALL_DIR $CONFIG_DIR $LOG_DIR"; then
            safe_exec "chown -R root:root $INSTALL_DIR $CONFIG_DIR"
            safe_exec "chmod 755 $INSTALL_DIR $CONFIG_DIR $LOG_DIR"
            log_info "已创建系统目录结构"
        else
            # 回退到用户目录
            mkdir -p "$HOME/.config/chisel" "$HOME/.local/share/chisel/logs" "$HOME/.local/share/chisel"
            log_info "已创建用户目录结构"
        fi
    else
        # 纯用户级安装
        mkdir -p "$HOME/.config/chisel" "$HOME/.local/share/chisel/logs" "$HOME/.local/share/chisel"
        log_info "已创建用户目录结构"
    fi
}

# 安装脚本文件
install_scripts() {
    local script_dir
    if check_root; then
        script_dir="$INSTALL_DIR"
    else
        script_dir="$HOME/.local/share/chisel"
    fi
    
    # 复制脚本文件到安装目录
    if [[ -f "chisel-server.sh" ]]; then
        cp chisel-server.sh "$script_dir/"
        chmod +x "$script_dir/chisel-server.sh"
        log_info "已安装服务端脚本"
    fi
    
    if [[ -f "chisel-client.sh" ]]; then
        cp chisel-client.sh "$script_dir/"
        chmod +x "$script_dir/chisel-client.sh"
        log_info "已安装客户端脚本"
    fi
    
    if [[ -f "chisel-manager.sh" ]]; then
        cp chisel-manager.sh "$script_dir/"
        chmod +x "$script_dir/chisel-manager.sh"
        log_info "已安装管理脚本"
    fi
}

# 安装配置文件
install_configs() {
    local config_dir
    if check_root; then
        config_dir="$CONFIG_DIR"
    else
        config_dir="$HOME/.config/chisel"
    fi
    
    # 复制配置文件
    for config in chisel-server.conf chisel-client.conf users.json; do
        if [[ -f "$config" ]]; then
            cp "$config" "$config_dir/"
            log_info "已安装配置文件: $config"
        fi
    done
}

# 安装 systemd 服务（需要管理员权限）
install_systemd_services() {
    if check_root; then
        # root 用户直接安装
        for service in chisel-server.service chisel-client.service; do
            if [[ -f "$service" ]]; then
                cp "$service" "$SYSTEMD_DIR/"
                log_info "已安装 systemd 服务: $service"
            fi
        done
        systemctl daemon-reload
        log_info "已重新加载 systemd 配置"
    elif check_sudo; then
        # 有 sudo 权限的用户
        for service in chisel-server.service chisel-client.service; do
            if [[ -f "$service" ]]; then
                if safe_exec "cp $service $SYSTEMD_DIR/"; then
                    log_info "已安装 systemd 服务: $service"
                else
                    log_warn "无法安装 systemd 服务: $service"
                fi
            fi
        done
        if safe_exec "systemctl daemon-reload"; then
            log_info "已重新加载 systemd 配置"
        fi
    else
        # 无管理员权限
        log_warn "跳过 systemd 服务安装（需要管理员权限）"
        log_info "低权限用户可以使用以下方式实现自启动："
        log_info "1. 添加到 ~/.bashrc: $HOME/.local/share/chisel/chisel-client.sh start"
        log_info "2. 使用 crontab: @reboot $HOME/.local/share/chisel/chisel-client.sh start"
        log_info "3. 使用 systemd 用户服务（如果支持）"
    fi
}

# 主安装函数
main() {
    log_info "开始安装 Chisel 代理服务器集群管理方案..."
    
    # 检查权限
    if check_root; then
        log_info "检测到 root 权限，将进行系统级安装"
    else
        log_info "检测到普通用户权限，将进行用户级安装"
    fi
    
    # 执行安装步骤
    download_chisel
    create_directories
    install_scripts
    install_configs
    install_systemd_services
    
    log_info "安装完成！"
    
    # 显示后续步骤
    echo
    log_info "后续步骤："
    if check_root; then
        echo "1. 编辑配置文件: $CONFIG_DIR/chisel-server.conf 或 $CONFIG_DIR/chisel-client.conf"
        echo "2. 启动服务端: $INSTALL_DIR/chisel-server.sh start"
        echo "3. 启动客户端: $INSTALL_DIR/chisel-client.sh start"
        echo "4. 查看状态: $INSTALL_DIR/chisel-manager.sh status"
        echo "5. 启用自启动: systemctl enable chisel-client"
    else
        echo "1. 编辑配置文件: $HOME/.config/chisel/chisel-client.conf"
        echo "2. 启动客户端: $HOME/.local/share/chisel/chisel-client.sh start"
        echo "3. 查看状态: $HOME/.local/share/chisel/chisel-manager.sh status"
    fi
}

# 执行主函数
main "$@"
