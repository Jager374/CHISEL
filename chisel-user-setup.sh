#!/bin/bash

# Chisel 低权限用户专用安装和配置脚本
# 版本: 1.0
# 描述: 专为无 sudo 权限的用户设计的 chisel 安装和配置工具

set -eo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 用户级路径配置
USER_BIN_DIR="$HOME/.local/bin"
USER_CONFIG_DIR="$HOME/.config/chisel"
USER_DATA_DIR="$HOME/.local/share/chisel"
USER_LOG_DIR="$USER_DATA_DIR/logs"
USER_SYSTEMD_DIR="$HOME/.config/systemd/user"

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

# 检查必要工具
check_requirements() {
    local missing=()
    
    # 检查下载工具
    if ! command -v wget >/dev/null 2>&1 && ! command -v curl >/dev/null 2>&1; then
        missing+=("wget 或 curl")
    fi
    
    # 检查解压工具
    if ! command -v gunzip >/dev/null 2>&1; then
        missing+=("gunzip")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少必要工具: ${missing[*]}"
        log_error "请联系系统管理员安装这些工具"
        exit 1
    fi
}

# 创建用户目录结构
create_user_directories() {
    log_info "创建用户目录结构..."
    
    mkdir -p "$USER_BIN_DIR"
    mkdir -p "$USER_CONFIG_DIR"
    mkdir -p "$USER_DATA_DIR"
    mkdir -p "$USER_LOG_DIR"
    mkdir -p "$USER_SYSTEMD_DIR"
    
    log_info "目录创建完成:"
    log_info "  二进制文件: $USER_BIN_DIR"
    log_info "  配置文件: $USER_CONFIG_DIR"
    log_info "  数据文件: $USER_DATA_DIR"
    log_info "  日志文件: $USER_LOG_DIR"
}

# 下载并安装 chisel
install_chisel() {
    log_info "下载并安装 chisel..."
    
    # 检测架构
    local arch=$(uname -m)
    case $arch in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        armv7l) arch="armv7" ;;
        *) log_error "不支持的架构: $arch"; exit 1 ;;
    esac
    
    local version="v1.10.1"
    local download_url="https://github.com/jpillora/chisel/releases/download/${version}/chisel_${version#v}_linux_${arch}.gz"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    cd "$temp_dir"
    
    # 下载文件
    log_info "从 $download_url 下载..."
    if command -v wget >/dev/null 2>&1; then
        wget -q "$download_url" -O chisel.gz
    else
        curl -sL "$download_url" -o chisel.gz
    fi
    
    # 解压并安装
    gunzip chisel.gz
    chmod +x chisel
    mv chisel "$USER_BIN_DIR/"
    
    # 清理
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    log_info "chisel 已安装到 $USER_BIN_DIR/chisel"
}

# 配置 PATH 环境变量
configure_path() {
    log_info "配置 PATH 环境变量..."
    
    # 检查 PATH 是否已包含用户 bin 目录
    if [[ ":$PATH:" != *":$USER_BIN_DIR:"* ]]; then
        log_warn "$USER_BIN_DIR 不在 PATH 中"
        
        # 添加到 .bashrc
        local bashrc="$HOME/.bashrc"
        local path_line="export PATH=\"\$HOME/.local/bin:\$PATH\""
        
        if [[ -f "$bashrc" ]] && ! grep -q "$path_line" "$bashrc"; then
            echo "" >> "$bashrc"
            echo "# Added by chisel-user-setup" >> "$bashrc"
            echo "$path_line" >> "$bashrc"
            log_info "已添加 PATH 配置到 $bashrc"
            log_warn "请运行 'source ~/.bashrc' 或重新登录以生效"
        fi
        
        # 临时设置 PATH
        export PATH="$USER_BIN_DIR:$PATH"
    else
        log_info "PATH 配置正确"
    fi
}

# 安装脚本文件
install_scripts() {
    log_info "安装管理脚本..."
    
    # 复制脚本文件
    for script in chisel-client.sh chisel-manager.sh; do
        if [[ -f "$script" ]]; then
            cp "$script" "$USER_DATA_DIR/"
            chmod +x "$USER_DATA_DIR/$script"
            log_info "已安装: $script"
        else
            log_warn "脚本文件不存在: $script"
        fi
    done
}

# 安装配置文件
install_configs() {
    log_info "安装配置文件..."
    
    # 复制配置文件
    for config in chisel-client.conf users.json; do
        if [[ -f "$config" ]]; then
            cp "$config" "$USER_CONFIG_DIR/"
            log_info "已安装配置: $config"
        fi
    done
    
    # 修改配置文件中的路径
    if [[ -f "$USER_CONFIG_DIR/chisel-client.conf" ]]; then
        sed -i "s|/var/log/chisel|$USER_LOG_DIR|g" "$USER_CONFIG_DIR/chisel-client.conf"
        sed -i "s|/var/run|$USER_DATA_DIR|g" "$USER_CONFIG_DIR/chisel-client.conf"
        log_info "已更新配置文件路径"
    fi
}

# 设置用户级 systemd 服务
setup_user_systemd() {
    log_info "设置用户级 systemd 服务..."
    
    # 检查 systemd 用户服务支持
    if ! systemctl --user status >/dev/null 2>&1; then
        log_warn "系统不支持用户级 systemd 服务"
        return 1
    fi
    
    # 安装用户服务文件
    if [[ -f "chisel-client-user.service" ]]; then
        cp "chisel-client-user.service" "$USER_SYSTEMD_DIR/chisel-client.service"
        
        # 重新加载用户服务
        systemctl --user daemon-reload
        
        log_info "用户级 systemd 服务已安装"
        log_info "启用服务: systemctl --user enable chisel-client"
        log_info "启动服务: systemctl --user start chisel-client"
        log_info "查看状态: systemctl --user status chisel-client"
        
        return 0
    else
        log_warn "用户服务文件不存在: chisel-client-user.service"
        return 1
    fi
}

# 设置 crontab 自启动
setup_crontab_autostart() {
    log_info "设置 crontab 自启动..."
    
    local cron_line="@reboot $USER_DATA_DIR/chisel-client.sh start >/dev/null 2>&1"
    
    # 检查是否已存在
    if crontab -l 2>/dev/null | grep -q "$USER_DATA_DIR/chisel-client.sh"; then
        log_info "crontab 自启动已配置"
        return 0
    fi
    
    # 添加到 crontab
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    log_info "已添加 crontab 自启动配置"
    log_info "重启后将自动启动 chisel 客户端"
}

# 创建便捷命令
create_convenience_commands() {
    log_info "创建便捷命令..."
    
    # 创建 chisel 命令别名脚本
    cat > "$USER_BIN_DIR/chisel-start" << EOF
#!/bin/bash
$USER_DATA_DIR/chisel-client.sh start
EOF
    
    cat > "$USER_BIN_DIR/chisel-stop" << EOF
#!/bin/bash
$USER_DATA_DIR/chisel-client.sh stop
EOF
    
    cat > "$USER_BIN_DIR/chisel-status" << EOF
#!/bin/bash
$USER_DATA_DIR/chisel-client.sh status
EOF
    
    cat > "$USER_BIN_DIR/chisel-logs" << EOF
#!/bin/bash
$USER_DATA_DIR/chisel-client.sh logs
EOF
    
    chmod +x "$USER_BIN_DIR"/chisel-*
    
    log_info "已创建便捷命令:"
    log_info "  chisel-start  - 启动客户端"
    log_info "  chisel-stop   - 停止客户端"
    log_info "  chisel-status - 查看状态"
    log_info "  chisel-logs   - 查看日志"
}

# 显示配置指南
show_configuration_guide() {
    echo
    log_info "=== 配置指南 ==="
    echo
    echo "1. 编辑客户端配置文件:"
    echo "   nano $USER_CONFIG_DIR/chisel-client.conf"
    echo
    echo "2. 主要配置项:"
    echo "   SERVER_URL=\"http://your-server.com:8080\""
    echo "   AUTH_CREDENTIALS=\"username:password\""
    echo "   REMOTE_TUNNELS=\"socks\""
    echo
    echo "3. 启动客户端:"
    echo "   $USER_DATA_DIR/chisel-client.sh start"
    echo "   # 或使用便捷命令: chisel-start"
    echo
    echo "4. 查看状态:"
    echo "   $USER_DATA_DIR/chisel-client.sh status"
    echo "   # 或使用便捷命令: chisel-status"
    echo
    echo "5. 设置自启动 (选择一种方式):"
    echo "   a) 用户级 systemd 服务:"
    echo "      systemctl --user enable chisel-client"
    echo "      systemctl --user start chisel-client"
    echo
    echo "   b) crontab 自启动 (已自动配置)"
    echo
    echo "6. 查看日志:"
    echo "   tail -f $USER_LOG_DIR/client.log"
    echo "   # 或使用便捷命令: chisel-logs"
}

# 主函数
main() {
    echo "=== Chisel 低权限用户安装工具 ==="
    echo
    
    # 检查是否为 root 用户
    if [[ $EUID -eq 0 ]]; then
        log_warn "检测到 root 用户，建议使用标准安装脚本"
        log_warn "继续使用用户级安装? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
    
    # 执行安装步骤
    check_requirements
    create_user_directories
    install_chisel
    configure_path
    install_scripts
    install_configs
    
    # 设置自启动 (尝试多种方式)
    if ! setup_user_systemd; then
        setup_crontab_autostart
    fi
    
    create_convenience_commands
    
    log_info "安装完成！"
    show_configuration_guide
}

# 执行主函数
main "$@"
