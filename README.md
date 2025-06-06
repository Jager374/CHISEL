# Chisel 代理服务器完整部署指南

## 项目概述

这是一套基于 [jpillora/chisel](https://github.com/jpillora/chisel) 工具的完整代理服务器集群管理方案，提供了从简单使用到企业级部署的全套解决方案。

### 核心特性

- 🚀 **多种部署方式** - 从一键脚本到完整集群管理
- 🔐 **权限分级管理** - 支持高权限和低权限主机的不同功能
- 🔄 **自动重连机制** - 客户端断线自动重连，确保服务稳定性
- 📊 **集群化管理** - 统一管理多个客户端和服务端实例
- 📝 **完整日志记录** - 详细的操作日志和状态监控
- ⚙️ **系统服务集成** - 支持 systemd 自启动服务
- 🛠️ **配置文件管理** - 灵活的配置文件系统
- 🏥 **健康检查** - 自动检测系统状态和问题

### 适用场景

- **个人用户**: 快速搭建代理服务，突破网络限制
- **开发团队**: 内网穿透，远程开发环境访问
- **企业用户**: 安全的远程访问解决方案
- **运维团队**: 集群化的代理服务管理

## 系统要求

### 服务端要求
- **操作系统**: Ubuntu 22.04 LTS / CentOS 7+ / Debian 10+
- **内存**: 最低 512MB，推荐 1GB+
- **网络**: 公网 IP 或端口转发，默认端口 8080
- **权限**: 建议具有 sudo 权限

### 客户端要求
- **操作系统**: 任意 Linux 发行版
- **架构**: x86_64、ARM64、ARMv7
- **内存**: 最低 256MB
- **网络**: 能够访问服务端的网络连接

## 部署方案选择

根据您的需求和技术水平，选择合适的部署方案：

### 方案对比

| 特性 | 极简版本 | 完整版本 | 低权限版本 |
|------|----------|----------|------------|
| **文件数量** | 2个脚本 | 14个文件 | 专用脚本 |
| **配置复杂度** | 命令行参数 | 配置文件 | 简化配置 |
| **学习成本** | 5分钟 | 30分钟 | 15分钟 |
| **功能完整性** | 核心功能 | 全部功能 | 核心功能 |
| **适用场景** | 个人快速使用 | 企业级管理 | 受限环境 |
| **权限要求** | 自动检测 | 建议sudo | 无需sudo |

### 选择建议

- **🚀 新手用户**: 选择极简版本，5分钟快速上手
- **🏢 企业用户**: 选择完整版本，功能全面，管理便捷
- **🔒 受限环境**: 选择低权限版本，无需管理员权限

---

## 方案一：极简版本（推荐新手）

### 特点
- **一个脚本搞定一切** - 无需复杂配置
- **自动下载安装** - 首次运行自动安装 chisel
- **智能权限检测** - 自动选择安装方式
- **零配置启动** - 一条命令即可使用

### 快速开始

#### 1. 下载脚本
```bash
# 客户端脚本（最常用）
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-simple.sh
chmod +x chisel-simple.sh

# 服务端脚本（可选）
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-server-simple.sh
chmod +x chisel-server-simple.sh
```

#### 2. 一键启动客户端
```bash
# 启动 SOCKS5 代理（最常用）
./chisel-simple.sh start http://your-server.com:8080 username:password socks

# 启动端口转发
./chisel-simple.sh start http://your-server.com:8080 username:password "3000:localhost:3000"

# 启动反向隧道
./chisel-simple.sh start http://your-server.com:8080 username:password "R:2222:localhost:22"
```

#### 3. 管理命令
```bash
./chisel-simple.sh status    # 查看状态
./chisel-simple.sh stop      # 停止服务
./chisel-simple.sh logs      # 查看日志
./chisel-simple.sh config    # 配置向导
```

> 📖 **详细说明**: [极简版使用指南](README-SIMPLE.md)

---

## 方案二：完整版本（企业级管理）

### 特点
- **完整功能集** - 包含所有高级功能
- **配置文件管理** - 灵活的配置系统
- **集群管理** - 统一管理多个实例
- **系统服务集成** - systemd 自启动支持
- **健康检查** - 自动监控和故障恢复

### 安装部署

#### 1. 下载安装脚本
```bash
# 下载完整安装脚本
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-install.sh
chmod +x chisel-install.sh

# 高权限用户（推荐）
sudo ./chisel-install.sh

# 普通用户（自动检测权限）
./chisel-install.sh
```

#### 2. 服务端配置
```bash
# 编辑服务端配置
sudo nano /etc/chisel/chisel-server.conf

# 关键配置项
SERVER_HOST="0.0.0.0"           # 监听地址
SERVER_PORT="8080"              # 监听端口
ENABLE_SOCKS5="true"            # 启用SOCKS5
ENABLE_REVERSE="true"           # 启用反向代理
AUTH_FILE="/etc/chisel/users.json"  # 用户认证文件
```

#### 3. 客户端配置
```bash
# 编辑客户端配置
sudo nano /etc/chisel/chisel-client.conf

# 关键配置项
SERVER_URL="http://your-server.com:8080"    # 服务器地址
AUTH_CREDENTIALS="username:password"         # 认证信息
REMOTE_TUNNELS="socks"                      # 隧道配置
ENABLE_RECONNECT="true"                     # 自动重连
```

#### 4. 用户认证配置
```bash
# 编辑用户文件
sudo nano /etc/chisel/users.json

# 示例配置
{
  "admin:admin123": [".*"],
  "client1:password123": [".*:.*", "R:.*:.*"],
  "socks_user:socks123": ["socks"]
}
```

#### 5. 启动服务
```bash
# 服务端管理
sudo /opt/chisel/chisel-server.sh start     # 启动
sudo /opt/chisel/chisel-server.sh status    # 状态
sudo /opt/chisel/chisel-server.sh logs      # 日志

# 客户端管理
sudo /opt/chisel/chisel-client.sh start     # 启动
sudo /opt/chisel/chisel-client.sh status    # 状态
sudo /opt/chisel/chisel-client.sh test      # 测试

# 集群管理
sudo /opt/chisel/chisel-manager.sh status   # 整体状态
sudo /opt/chisel/chisel-manager.sh health   # 健康检查
```

#### 6. 系统服务管理
```bash
# 启用自启动
sudo systemctl enable chisel-server
sudo systemctl enable chisel-client

# 服务管理
sudo systemctl start chisel-client
sudo systemctl stop chisel-client
sudo systemctl restart chisel-client
sudo systemctl status chisel-client

# 查看日志
sudo journalctl -u chisel-client -f
```

---

## 方案三：低权限版本（受限环境）

### 特点
- **无需 sudo 权限** - 完全在用户目录下运行
- **用户级安装** - 不影响系统环境
- **自启动支持** - 支持用户级自启动机制
- **完整功能** - 保留所有核心代理功能

### 快速部署
```bash
# 下载低权限专用脚本
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-user-setup.sh
chmod +x chisel-user-setup.sh

# 一键安装（无需sudo）
./chisel-user-setup.sh
```

### 手动安装步骤
```bash
# 1. 创建目录结构
mkdir -p ~/.local/bin ~/.config/chisel ~/.local/share/chisel/logs

# 2. 下载并安装 chisel
ARCH=$(uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
VERSION="v1.10.1"
wget "https://github.com/jpillora/chisel/releases/download/${VERSION}/chisel_${VERSION#v}_linux_${ARCH}.gz"
gunzip "chisel_${VERSION#v}_linux_${ARCH}.gz"
chmod +x "chisel_${VERSION#v}_linux_${ARCH}"
mv "chisel_${VERSION#v}_linux_${ARCH}" ~/.local/bin/chisel

# 3. 配置环境变量
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 4. 复制配置文件
cp chisel-client.conf ~/.config/chisel/
```

### 使用方法
```bash
# 启动客户端
~/.local/share/chisel/chisel-client.sh start

# 查看状态
~/.local/share/chisel/chisel-client.sh status

# 停止服务
~/.local/share/chisel/chisel-client.sh stop

# 查看日志
~/.local/share/chisel/chisel-client.sh logs
```

### 自启动配置
```bash
# 方法1: crontab自启动
crontab -e
# 添加: @reboot ~/.local/share/chisel/chisel-client.sh start

# 方法2: 用户级systemd服务（如果支持）
systemctl --user enable chisel-client
systemctl --user start chisel-client

# 方法3: .bashrc自启动
echo '~/.local/share/chisel/chisel-client.sh start >/dev/null 2>&1 &' >> ~/.bashrc
```

> 📖 **详细说明**: [低权限用户使用指南](README-LOW-PRIVILEGE.md)

---

## 不同机器类型的部署指南

### 🖥️ 个人电脑/笔记本（客户端）

#### 场景特点
- 通常具有管理员权限
- 主要用作客户端连接远程服务器
- 需要稳定的代理服务

#### 推荐方案
**极简版本** - 快速上手，操作简单

```bash
# 1. 下载脚本
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-simple.sh
chmod +x chisel-simple.sh

# 2. 启动SOCKS5代理
./chisel-simple.sh start http://your-server.com:8080 username:password socks

# 3. 配置浏览器代理
# SOCKS5: 127.0.0.1:1080
```

#### 开机自启动
```bash
# 添加到开机启动
(crontab -l 2>/dev/null; echo "@reboot $(pwd)/chisel-simple.sh start http://server:8080 user:pass socks") | crontab -
```

### 🖥️ 云服务器/VPS（服务端）

#### 场景特点
- 具有公网IP
- 通常有root权限
- 需要稳定运行，提供服务

#### 推荐方案
**完整版本** - 功能全面，管理便捷

```bash
# 1. 安装部署
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-install.sh
chmod +x chisel-install.sh
sudo ./chisel-install.sh

# 2. 配置服务端
sudo nano /etc/chisel/chisel-server.conf
# 设置监听端口、认证等

# 3. 启动服务
sudo /opt/chisel/chisel-server.sh start

# 4. 启用自启动
sudo systemctl enable chisel-server
```

#### 安全配置
```bash
# 配置防火墙
sudo ufw allow 8080/tcp

# 设置用户认证
sudo nano /etc/chisel/users.json
{
  "client1:strongpassword": ["socks", ".*:.*"],
  "admin:adminpass": [".*"]
}
```

### 💼 办公电脑（受限环境）

#### 场景特点
- 无管理员权限
- 网络访问受限
- 需要突破网络限制

#### 推荐方案
**低权限版本** - 无需sudo，用户级安装

```bash
# 1. 下载用户级安装脚本
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-user-setup.sh
chmod +x chisel-user-setup.sh

# 2. 用户级安装
./chisel-user-setup.sh

# 3. 启动客户端
~/.local/share/chisel/chisel-client.sh start
```

#### 隐蔽运行
```bash
# 后台静默运行
nohup ~/.local/share/chisel/chisel-client.sh start >/dev/null 2>&1 &

# 添加到用户自启动
echo '~/.local/share/chisel/chisel-client.sh start >/dev/null 2>&1 &' >> ~/.bashrc
```

### 🏠 家庭路由器/NAS（ARM设备）

#### 场景特点
- ARM架构处理器
- 资源有限
- 需要长期稳定运行

#### 推荐方案
**极简版本** - 资源占用少，稳定可靠

```bash
# 1. 检查架构
uname -m  # 确认是 aarch64 或 armv7l

# 2. 下载适配脚本
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-simple.sh
chmod +x chisel-simple.sh

# 3. 启动（自动下载ARM版本）
./chisel-simple.sh start http://server:8080 user:pass socks

# 4. 设置开机自启动
echo "$(pwd)/chisel-simple.sh start http://server:8080 user:pass socks &" >> /etc/rc.local
```

### 🐳 Docker容器环境

#### 场景特点
- 容器化部署
- 资源隔离
- 易于管理和扩展

#### 推荐方案
**容器化部署**

```dockerfile
# Dockerfile
FROM alpine:latest
RUN apk add --no-cache wget bash
COPY chisel-simple.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/chisel-simple.sh
CMD ["/usr/local/bin/chisel-simple.sh", "start", "$SERVER_URL", "$AUTH", "$TUNNELS"]
```

```bash
# 构建和运行
docker build -t chisel-client .
docker run -d --name chisel-client \
  -e SERVER_URL="http://server:8080" \
  -e AUTH="user:pass" \
  -e TUNNELS="socks" \
  chisel-client
```

---

## 常用使用场景配置

### 🌐 场景1：SOCKS5代理上网

#### 客户端配置
```bash
# 极简版本
./chisel-simple.sh start http://your-server.com:8080 username:password socks

# 完整版本配置文件
SERVER_URL="http://your-server.com:8080"
AUTH_CREDENTIALS="username:password"
REMOTE_TUNNELS="socks"
```

#### 使用代理
```bash
# 浏览器设置
# SOCKS5代理: 127.0.0.1:1080

# 命令行使用
curl --socks5 127.0.0.1:1080 http://httpbin.org/ip

# 全局代理（Linux）
export http_proxy=socks5://127.0.0.1:1080
export https_proxy=socks5://127.0.0.1:1080
```

### 🔗 场景2：端口转发

#### 转发Web服务
```bash
# 将本地3000端口转发到远程服务
./chisel-simple.sh start http://server:8080 user:pass "3000:target-server:80"

# 访问
curl http://localhost:3000
```

#### 转发数据库连接
```bash
# 转发MySQL连接
./chisel-simple.sh start http://server:8080 user:pass "3306:db-server:3306"

# 本地连接
mysql -h 127.0.0.1 -P 3306 -u user -p
```

### 🔄 场景3：反向隧道（内网穿透）

#### SSH反向隧道
```bash
# 客户端配置
./chisel-simple.sh start http://server:8080 user:pass "R:2222:localhost:22"

# 从服务端连接
ssh -p 2222 user@localhost
```

#### Web服务反向代理
```bash
# 将内网Web服务暴露到公网
./chisel-simple.sh start http://server:8080 user:pass "R:8080:localhost:80"

# 通过服务端访问
curl http://server-ip:8080
```

### 🔀 场景4：多隧道组合

#### 同时使用多种功能
```bash
# 组合配置
./chisel-simple.sh start http://server:8080 user:pass "socks 3000:localhost:3000 R:2222:localhost:22"
```

#### 配置文件方式
```bash
# /etc/chisel/chisel-client.conf 或 ~/.config/chisel/chisel-client.conf
REMOTE_TUNNELS="socks 8080:google.com:80 3000:localhost:3000"
REVERSE_TUNNELS="R:2222:localhost:22 R:3389:localhost:3389"
```

---

## 集群管理功能（完整版本）

### 集群管理工具
```bash
# 查看整体状态
sudo /opt/chisel/chisel-manager.sh status

# 启动所有服务
sudo /opt/chisel/chisel-manager.sh start

# 停止所有服务
sudo /opt/chisel/chisel-manager.sh stop

# 重启所有服务
sudo /opt/chisel/chisel-manager.sh restart

# 查看日志
sudo /opt/chisel/chisel-manager.sh logs

# 健康检查
sudo /opt/chisel/chisel-manager.sh health

# 配置管理
sudo /opt/chisel/chisel-manager.sh config list
sudo /opt/chisel/chisel-manager.sh config edit server
sudo /opt/chisel/chisel-manager.sh config backup
```

### 系统服务管理
```bash
# 启用自启动
sudo systemctl enable chisel-server
sudo systemctl enable chisel-client

# 服务管理
sudo systemctl start chisel-client
sudo systemctl stop chisel-client
sudo systemctl restart chisel-client
sudo systemctl status chisel-client

# 查看日志
sudo journalctl -u chisel-client -f
sudo journalctl -u chisel-server -f
```

### 配置文件详解

#### 服务端配置 (/etc/chisel/chisel-server.conf)
```bash
# 基础网络配置
SERVER_HOST="0.0.0.0"           # 监听地址
SERVER_PORT="8080"              # 监听端口

# 安全配置
KEY_FILE="/etc/chisel/server.key"      # SSH密钥文件
AUTH_FILE="/etc/chisel/users.json"     # 用户认证文件
AUTH_USER="admin:password123"           # 单用户认证

# 功能配置
ENABLE_SOCKS5="true"            # 启用SOCKS5代理
ENABLE_REVERSE="true"           # 启用反向端口转发
BACKEND_PROXY=""                # 后端代理服务器

# TLS/SSL配置
ENABLE_TLS="false"              # 启用TLS
TLS_CERT=""                     # TLS证书文件
TLS_KEY=""                      # TLS私钥文件
TLS_DOMAIN=""                   # Let's Encrypt域名
```

#### 客户端配置 (/etc/chisel/chisel-client.conf)
```bash
# 服务器连接
SERVER_URL="http://server:8080"         # 服务器地址
SERVER_FINGERPRINT=""                   # 服务器指纹验证
AUTH_CREDENTIALS="user:pass"            # 认证信息

# 隧道配置
REMOTE_TUNNELS="socks"                  # 远程隧道
REVERSE_TUNNELS="R:2222:localhost:22"   # 反向隧道

# 自动重连
ENABLE_RECONNECT="true"                 # 启用自动重连
RECONNECT_INTERVAL="10"                 # 重连间隔（秒）
MAX_RETRY_COUNT="0"                     # 最大重试次数（0=无限）
```

#### 用户认证配置 (/etc/chisel/users.json)
```json
{
  "admin:admin123": [".*"],
  "client1:password123": [".*:.*", "R:.*:.*"],
  "readonly:readonly789": [".*:80", ".*:443"],
  "socks_user:socks123": ["socks"]
}
```

---

## 故障排除指南

### 🔧 常见问题解决

#### 1. 连接失败
**问题现象**: 客户端无法连接到服务器

**排查步骤**:
```bash
# 检查网络连通性
ping server-ip
telnet server-ip 8080

# 检查服务端是否运行
# 服务端执行
netstat -tlnp | grep :8080
ps aux | grep chisel

# 检查防火墙设置
sudo ufw status
sudo iptables -L | grep 8080

# 检查服务端日志
tail -f /var/log/chisel/server.log
```

**解决方案**:
```bash
# 开放防火墙端口
sudo ufw allow 8080/tcp

# 重启服务端
sudo /opt/chisel/chisel-server.sh restart

# 检查配置文件
sudo nano /etc/chisel/chisel-server.conf
```

#### 2. 认证失败
**问题现象**: 客户端连接被拒绝，提示认证错误

**排查步骤**:
```bash
# 检查用户配置文件
cat /etc/chisel/users.json

# 检查客户端认证信息
grep AUTH_CREDENTIALS /etc/chisel/chisel-client.conf

# 查看认证相关日志
grep -i "auth" /var/log/chisel/server.log
```

**解决方案**:
```bash
# 更新用户认证文件
sudo nano /etc/chisel/users.json
{
  "username:password": [".*"]
}

# 更新客户端认证信息
sudo nano /etc/chisel/chisel-client.conf
AUTH_CREDENTIALS="username:password"

# 重启服务
sudo /opt/chisel/chisel-server.sh restart
sudo /opt/chisel/chisel-client.sh restart
```

#### 3. 端口被占用
**问题现象**: 启动失败，提示端口已被占用

**排查步骤**:
```bash
# 检查端口占用
netstat -tlnp | grep :1080
lsof -i :1080

# 查找占用进程
ps aux | grep chisel
```

**解决方案**:
```bash
# 停止占用进程
sudo pkill chisel

# 或使用其他端口
./chisel-simple.sh start http://server:8080 user:pass "5000:localhost:5000"
```

#### 4. 权限问题
**问题现象**: 无法创建文件或目录，权限被拒绝

**排查步骤**:
```bash
# 检查目录权限
ls -la /etc/chisel/
ls -la ~/.local/bin/

# 检查文件权限
ls -la ~/.local/bin/chisel
```

**解决方案**:
```bash
# 修复权限
chmod +x ~/.local/bin/chisel
chmod 755 ~/.config/chisel/

# 或使用低权限版本
./chisel-user-setup.sh
```

### 📊 日志分析

#### 日志文件位置
```bash
# 系统级安装
/var/log/chisel/server.log      # 服务端日志
/var/log/chisel/client.log      # 客户端日志

# 用户级安装
~/.local/share/chisel/logs/client.log

# systemd日志
sudo journalctl -u chisel-server -f
sudo journalctl -u chisel-client -f
```

#### 常用日志命令
```bash
# 查看最近日志
tail -20 /var/log/chisel/client.log

# 实时监控日志
tail -f /var/log/chisel/client.log

# 搜索错误信息
grep -i "error\|fail\|denied" /var/log/chisel/client.log

# 查看连接日志
grep -i "connect\|tunnel" /var/log/chisel/client.log
```

### ⚡ 性能优化

#### 连接参数优化
```bash
# 客户端配置优化
KEEPALIVE="30s"                 # 保持连接
MAX_RETRY_INTERVAL="2m"         # 最大重试间隔
RECONNECT_INTERVAL="5"          # 重连间隔

# 服务端配置优化
SERVER_KEEPALIVE="30s"          # 服务端保持连接
MAX_CONNECTIONS="1000"          # 最大连接数
```

#### 系统级优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# 优化网络参数
echo "net.core.rmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
echo "net.core.wmem_max = 16777216" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

---

## 安全建议

### 🔒 基础安全配置

#### 1. 强密码策略
```bash
# 生成强密码
openssl rand -base64 32

# 用户认证配置示例
{
  "admin:$(openssl rand -base64 16)": [".*"],
  "client1:$(openssl rand -base64 16)": ["socks", ".*:80", ".*:443"]
}
```

#### 2. 服务器指纹验证
```bash
# 获取服务器指纹
chisel server --fingerprint

# 客户端配置指纹验证
SERVER_FINGERPRINT="your-server-fingerprint"
```

#### 3. 访问权限控制
```bash
# 精确的权限配置
{
  "readonly_user:password": [".*:80", ".*:443"],      # 只能访问HTTP/HTTPS
  "socks_user:password": ["socks"],                   # 只能使用SOCKS5
  "admin_user:password": [".*"],                      # 完全访问权限
  "tunnel_user:password": ["3000:.*:.*", "R:2222:.*:.*"]  # 特定隧道权限
}
```

#### 4. TLS加密传输
```bash
# 启用TLS（生产环境推荐）
ENABLE_TLS="true"
TLS_CERT="/path/to/cert.pem"
TLS_KEY="/path/to/key.pem"

# 使用Let's Encrypt
TLS_DOMAIN="your-domain.com"
```

#### 5. 防火墙配置
```bash
# 只开放必要端口
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 8080/tcp
sudo ufw enable

# 限制IP访问（可选）
sudo ufw allow from 192.168.1.0/24 to any port 8080
```

### 🛡️ 高级安全措施

#### 1. 定期更新
```bash
# 检查最新版本
curl -s https://api.github.com/repos/jpillora/chisel/releases/latest | grep tag_name

# 自动更新脚本
#!/bin/bash
CURRENT_VERSION=$(chisel --version 2>&1 | grep -o 'v[0-9.]*')
LATEST_VERSION=$(curl -s https://api.github.com/repos/jpillora/chisel/releases/latest | grep -o '"tag_name": "v[^"]*' | cut -d'"' -f4)

if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    echo "发现新版本: $LATEST_VERSION"
    # 执行更新逻辑
fi
```

#### 2. 日志监控
```bash
# 监控异常连接
grep -i "denied\|failed\|error" /var/log/chisel/server.log | tail -20

# 设置日志轮转
sudo nano /etc/logrotate.d/chisel
/var/log/chisel/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
```

#### 3. 进程监控
```bash
# 监控脚本
#!/bin/bash
if ! pgrep -f "chisel client" > /dev/null; then
    echo "$(date): Chisel client not running, restarting..." >> /var/log/chisel/monitor.log
    /opt/chisel/chisel-client.sh start
fi

# 添加到crontab
*/5 * * * * /path/to/monitor.sh
```

---

## 项目信息

### 📋 版本信息
- **项目版本**: 2.0
- **支持的 chisel 版本**: v1.10.1+
- **兼容系统**: Ubuntu 22.04+, CentOS 7+, Debian 10+, Alpine Linux
- **支持架构**: x86_64, ARM64, ARMv7

### 📁 文件结构
```
chisel/
├── README.md                    # 主要说明文档
├── README-SIMPLE.md             # 极简版使用指南
├── README-LOW-PRIVILEGE.md      # 低权限用户指南
├── chisel-install.sh            # 完整版安装脚本
├── chisel-user-setup.sh         # 低权限用户安装脚本
├── chisel-simple.sh             # 极简客户端脚本
├── chisel-server-simple.sh      # 极简服务端脚本
├── chisel-client.sh             # 完整版客户端管理脚本
├── chisel-server.sh             # 完整版服务端管理脚本
├── chisel-manager.sh            # 集群管理脚本
├── chisel-client.conf           # 客户端配置文件模板
├── chisel-server.conf           # 服务端配置文件模板
├── chisel-client.service        # systemd服务文件（客户端）
├── chisel-server.service        # systemd服务文件（服务端）
├── chisel-client-user.service   # 用户级systemd服务文件
├── users.json                   # 用户认证配置模板
├── test-chisel-setup.sh         # 安装测试脚本
└── test-simple.sh               # 简单功能测试脚本
```

### 🤝 贡献指南
欢迎提交 Issue 和 Pull Request 来改进这个项目：

1. **报告问题**: 使用 GitHub Issues 报告 bug 或提出功能请求
2. **提交代码**: Fork 项目，创建分支，提交 Pull Request
3. **改进文档**: 帮助完善文档和使用指南
4. **测试反馈**: 在不同环境下测试并反馈问题

### 📞 技术支持
如有问题或建议，请通过以下方式联系：
- **GitHub Issues**: [项目地址](https://github.com/your-repo/chisel)
- **文档问题**: 查看对应的专门指南文档
- **社区讨论**: 欢迎在 Issues 中讨论使用经验

### 📄 许可证
本项目采用 MIT 许可证，详见 LICENSE 文件。

---

## 快速参考

### 🚀 一分钟快速开始
```bash
# 1. 下载极简脚本
wget https://raw.githubusercontent.com/your-repo/chisel/main/chisel-simple.sh
chmod +x chisel-simple.sh

# 2. 启动SOCKS5代理
./chisel-simple.sh start http://your-server.com:8080 username:password socks

# 3. 配置浏览器代理: SOCKS5 127.0.0.1:1080
```

### 📚 相关文档
- [极简版使用指南](README-SIMPLE.md) - 5分钟快速上手
- [低权限用户指南](README-LOW-PRIVILEGE.md) - 无sudo权限环境使用
- [官方 chisel 文档](https://github.com/jpillora/chisel) - 原始项目文档

### 🔗 常用命令速查
```bash
# 状态查看
./chisel-simple.sh status
sudo /opt/chisel/chisel-manager.sh status

# 日志查看
./chisel-simple.sh logs
tail -f /var/log/chisel/client.log

# 服务管理
sudo systemctl status chisel-client
sudo systemctl restart chisel-client

# 测试连接
curl --socks5 127.0.0.1:1080 http://httpbin.org/ip
telnet server-ip 8080
```
