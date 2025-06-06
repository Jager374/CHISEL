# Chisel 低权限用户使用指南

## 概述

本指南专门为**无 sudo 权限**的低权限用户设计，提供完整的 chisel 客户端安装、配置和使用方案。

## 特别说明

⚠️ **重要**: 本方案专为无法使用 `sudo` 命令的用户设计，所有操作都在用户目录下进行，无需管理员权限。

## 快速开始

### 1. 一键安装（推荐）

```bash
# 下载并运行低权限用户专用安装脚本
./chisel-user-setup.sh
```

这个脚本会自动完成：
- ✅ 下载并安装 chisel 二进制文件到 `~/.local/bin/`
- ✅ 创建用户级目录结构
- ✅ 配置 PATH 环境变量
- ✅ 安装管理脚本和配置文件
- ✅ 设置自启动机制（systemd 用户服务或 crontab）
- ✅ 创建便捷命令

### 2. 手动安装

如果自动安装失败，可以按以下步骤手动安装：

#### 步骤 1: 创建目录结构
```bash
mkdir -p ~/.local/bin
mkdir -p ~/.config/chisel
mkdir -p ~/.local/share/chisel/logs
mkdir -p ~/.config/systemd/user
```

#### 步骤 2: 下载 chisel
```bash
# 检测系统架构
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    armv7l) ARCH="armv7" ;;
esac

# 下载并安装
VERSION="v1.10.1"
wget "https://github.com/jpillora/chisel/releases/download/${VERSION}/chisel_${VERSION#v}_linux_${ARCH}.gz"
gunzip "chisel_${VERSION#v}_linux_${ARCH}.gz"
chmod +x "chisel_${VERSION#v}_linux_${ARCH}"
mv "chisel_${VERSION#v}_linux_${ARCH}" ~/.local/bin/chisel
```

#### 步骤 3: 配置 PATH
```bash
# 添加到 .bashrc
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

#### 步骤 4: 复制配置文件
```bash
cp chisel-client.conf ~/.config/chisel/
cp chisel-client.sh ~/.local/share/chisel/
chmod +x ~/.local/share/chisel/chisel-client.sh
```

## 配置说明

### 客户端配置文件

编辑 `~/.config/chisel/chisel-client.conf`：

```bash
nano ~/.config/chisel/chisel-client.conf
```

关键配置项：
```bash
# 服务器地址（必须修改）
SERVER_URL="http://your-server.com:8080"

# 认证信息（如果服务器需要）
AUTH_CREDENTIALS="username:password"

# 隧道配置
REMOTE_TUNNELS="socks"  # SOCKS5 代理
# REMOTE_TUNNELS="3000:localhost:3000"  # 端口转发

# 日志配置（已自动设置为用户目录）
LOG_FILE="$HOME/.local/share/chisel/logs/client.log"
PID_FILE="$HOME/.local/share/chisel/chisel-client.pid"
```

## 使用方法

### 基本操作

```bash
# 启动客户端
~/.local/share/chisel/chisel-client.sh start

# 停止客户端
~/.local/share/chisel/chisel-client.sh stop

# 查看状态
~/.local/share/chisel/chisel-client.sh status

# 查看日志
~/.local/share/chisel/chisel-client.sh logs

# 测试连接
~/.local/share/chisel/chisel-client.sh test
```

### 便捷命令（安装脚本自动创建）

```bash
# 启动
chisel-start

# 停止
chisel-stop

# 状态
chisel-status

# 日志
chisel-logs
```

## 自启动配置

### 方法 1: 用户级 systemd 服务（推荐）

如果系统支持用户级 systemd 服务：

```bash
# 安装服务文件
cp chisel-client-user.service ~/.config/systemd/user/chisel-client.service

# 重新加载服务
systemctl --user daemon-reload

# 启用自启动
systemctl --user enable chisel-client

# 启动服务
systemctl --user start chisel-client

# 查看状态
systemctl --user status chisel-client

# 查看日志
journalctl --user -u chisel-client -f
```

### 方法 2: crontab 自启动

```bash
# 编辑 crontab
crontab -e

# 添加以下行
@reboot ~/.local/share/chisel/chisel-client.sh start >/dev/null 2>&1
```

### 方法 3: .bashrc 自启动

```bash
# 添加到 .bashrc（仅在交互式登录时启动）
echo '~/.local/share/chisel/chisel-client.sh start >/dev/null 2>&1 &' >> ~/.bashrc
```

## 常见问题解决

### 1. 命令找不到

**问题**: `chisel: command not found`

**解决方案**:
```bash
# 检查文件是否存在
ls -la ~/.local/bin/chisel

# 检查 PATH 配置
echo $PATH | grep -o "$HOME/.local/bin"

# 如果 PATH 不包含用户 bin 目录
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### 2. 权限问题

**问题**: `Permission denied`

**解决方案**:
```bash
# 确保文件有执行权限
chmod +x ~/.local/bin/chisel
chmod +x ~/.local/share/chisel/chisel-client.sh

# 检查目录权限
ls -la ~/.local/
ls -la ~/.config/
```

### 3. 连接失败

**问题**: 无法连接到服务器

**解决方案**:
```bash
# 测试网络连通性
telnet server-ip 8080

# 检查配置文件
cat ~/.config/chisel/chisel-client.conf

# 查看详细日志
tail -f ~/.local/share/chisel/logs/client.log
```

### 4. 自启动不工作

**问题**: 重启后服务没有自动启动

**解决方案**:

对于 systemd 用户服务：
```bash
# 检查服务状态
systemctl --user status chisel-client

# 确保用户服务在登录时启动
sudo loginctl enable-linger $USER
```

对于 crontab：
```bash
# 检查 crontab 配置
crontab -l

# 检查 cron 服务状态
ps aux | grep cron
```

## 目录结构

低权限用户安装后的目录结构：

```
$HOME/
├── .local/
│   ├── bin/
│   │   ├── chisel                 # chisel 二进制文件
│   │   ├── chisel-start          # 便捷启动命令
│   │   ├── chisel-stop           # 便捷停止命令
│   │   ├── chisel-status         # 便捷状态命令
│   │   └── chisel-logs           # 便捷日志命令
│   └── share/
│       └── chisel/
│           ├── chisel-client.sh  # 客户端管理脚本
│           ├── chisel-manager.sh # 集群管理脚本
│           └── logs/
│               └── client.log    # 客户端日志
├── .config/
│   ├── chisel/
│   │   ├── chisel-client.conf    # 客户端配置
│   │   └── users.json            # 用户认证配置
│   └── systemd/
│       └── user/
│           └── chisel-client.service  # 用户级服务文件
└── .bashrc                       # PATH 配置
```

## 使用场景示例

### 1. SOCKS5 代理

配置文件设置：
```bash
REMOTE_TUNNELS="socks"
```

使用代理：
```bash
# 启动客户端后，SOCKS5 代理监听在 127.0.0.1:1080
curl --socks5 127.0.0.1:1080 http://httpbin.org/ip
```

### 2. 端口转发

配置文件设置：
```bash
REMOTE_TUNNELS="8080:google.com:80"
```

访问转发端口：
```bash
curl http://localhost:8080
```

### 3. 反向隧道

配置文件设置：
```bash
REVERSE_TUNNELS="R:2222:localhost:22"
```

从服务端连接：
```bash
ssh -p 2222 user@server-ip
```

## 安全建议

1. **保护配置文件**: 确保配置文件权限正确
   ```bash
   chmod 600 ~/.config/chisel/chisel-client.conf
   ```

2. **使用强密码**: 如果使用密码认证，请设置复杂密码

3. **定期更新**: 保持 chisel 工具的最新版本

4. **监控日志**: 定期检查日志文件，发现异常及时处理

## 技术支持

如果遇到问题：

1. 查看日志文件：`~/.local/share/chisel/logs/client.log`
2. 运行健康检查：`~/.local/share/chisel/chisel-manager.sh health`
3. 检查配置文件语法
4. 测试网络连通性

## 限制说明

低权限用户的限制：
- ❌ 无法安装系统级 systemd 服务
- ❌ 无法使用系统级配置目录
- ❌ 无法监听特权端口（< 1024）
- ✅ 可以使用所有代理功能
- ✅ 可以设置用户级自启动
- ✅ 可以使用高端口进行端口转发

这些限制不影响 chisel 的核心功能使用。
