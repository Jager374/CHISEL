# Chisel 极简使用指南

## 概述

**一个脚本搞定一切！** 无需复杂配置，客户端只需要执行一个 shell 脚本即可完成所有操作。

## 文件说明

- **`chisel-simple.sh`** - 客户端一键脚本（主要使用）
- **`chisel-server-simple.sh`** - 服务端一键脚本

## 快速开始

### 客户端使用（最常用）

#### 1. 一键启动 SOCKS5 代理
```bash
# 下载脚本
wget https://raw.githubusercontent.com/your-repo/chisel-simple.sh
chmod +x chisel-simple.sh

# 启动 SOCKS5 代理（自动下载安装 chisel）
./chisel-simple.sh start http://server:8080 username:password socks
```

#### 2. 其他常用命令
```bash
# 查看状态
./chisel-simple.sh status

# 停止服务
./chisel-simple.sh stop

# 查看日志
./chisel-simple.sh logs

# 配置向导
./chisel-simple.sh config
```

### 服务端使用

```bash
# 下载脚本
wget https://raw.githubusercontent.com/your-repo/chisel-server-simple.sh
chmod +x chisel-server-simple.sh

# 启动服务端（自动下载安装 chisel）
./chisel-server-simple.sh start 8080

# 查看状态
./chisel-server-simple.sh status
```

## 使用场景

### 场景 1: SOCKS5 代理上网

**客户端操作**:
```bash
./chisel-simple.sh start http://your-server.com:8080 user:pass socks
```

**使用代理**:
```bash
# 浏览器设置 SOCKS5 代理: 127.0.0.1:1080
# 或命令行使用:
curl --socks5 127.0.0.1:1080 http://httpbin.org/ip
```

### 场景 2: 端口转发

**转发本地 3000 端口到远程服务**:
```bash
./chisel-simple.sh start http://server:8080 user:pass "3000:localhost:3000"
```

**访问**:
```bash
curl http://localhost:3000
```

### 场景 3: 反向 SSH 隧道

**客户端**:
```bash
./chisel-simple.sh start http://server:8080 user:pass "R:2222:localhost:22"
```

**从服务端连接**:
```bash
ssh -p 2222 user@localhost
```

### 场景 4: 多隧道组合

```bash
./chisel-simple.sh start http://server:8080 user:pass "socks 8080:google.com:80 R:2222:localhost:22"
```

## 命令参考

### 客户端命令

```bash
# 启动客户端
./chisel-simple.sh start [服务器] [认证] [隧道配置]

# 管理命令
./chisel-simple.sh stop          # 停止
./chisel-simple.sh status        # 状态
./chisel-simple.sh logs          # 日志
./chisel-simple.sh restart       # 重启
./chisel-simple.sh config        # 配置向导
./chisel-simple.sh install       # 仅安装 chisel
```

### 服务端命令

```bash
# 启动服务端
./chisel-server-simple.sh start [端口] [认证]

# 管理命令
./chisel-server-simple.sh stop          # 停止
./chisel-server-simple.sh status        # 状态
./chisel-server-simple.sh logs          # 日志
./chisel-server-simple.sh users list    # 用户管理
```

## 隧道配置语法

| 配置 | 说明 | 示例 |
|------|------|------|
| `socks` | SOCKS5 代理 | 监听 127.0.0.1:1080 |
| `本地端口:远程主机:远程端口` | 端口转发 | `3000:localhost:3000` |
| `R:本地端口:远程主机:远程端口` | 反向隧道 | `R:2222:localhost:22` |
| 多个配置用空格分隔 | 组合使用 | `"socks 8080:google.com:80"` |

## 自动功能

脚本会自动处理以下事项：

✅ **自动下载安装** - 首次运行自动下载 chisel 二进制文件  
✅ **智能权限检测** - 自动选择系统级或用户级安装  
✅ **路径配置** - 自动配置 PATH 环境变量  
✅ **目录创建** - 自动创建所需的配置和日志目录  
✅ **进程管理** - 自动管理进程启停和 PID 文件  

## 故障排除

### 1. 下载失败
```bash
# 检查网络连接
ping github.com

# 手动下载
wget https://github.com/jpillora/chisel/releases/download/v1.10.1/chisel_1.10.1_linux_amd64.gz
```

### 2. 权限问题
```bash
# 确保脚本有执行权限
chmod +x chisel-simple.sh

# 检查安装目录权限
ls -la ~/.local/bin/
```

### 3. 连接失败
```bash
# 测试服务器连通性
telnet server-ip 8080

# 查看详细日志
./chisel-simple.sh logs
```

### 4. 端口被占用
```bash
# 检查端口占用
netstat -tlnp | grep :1080

# 使用其他端口
./chisel-simple.sh start http://server:8080 user:pass "5000:localhost:5000"
```

## 高级用法

### 配置向导模式
```bash
./chisel-simple.sh config
```
交互式配置，适合新手使用。

### 批量部署
```bash
# 创建批量部署脚本
cat > deploy.sh << 'EOF'
#!/bin/bash
SERVER="http://your-server.com:8080"
AUTH="user:password"
TUNNELS="socks"

wget -O chisel-simple.sh https://raw.githubusercontent.com/your-repo/chisel-simple.sh
chmod +x chisel-simple.sh
./chisel-simple.sh start "$SERVER" "$AUTH" "$TUNNELS"
EOF

chmod +x deploy.sh
```

### 开机自启动
```bash
# 添加到 crontab
(crontab -l 2>/dev/null; echo "@reboot $(pwd)/chisel-simple.sh start http://server:8080 user:pass socks") | crontab -

# 或添加到 .bashrc
echo "$(pwd)/chisel-simple.sh start http://server:8080 user:pass socks &" >> ~/.bashrc
```

## 安全建议

1. **使用强密码**: 设置复杂的认证密码
2. **限制访问**: 在服务端配置防火墙规则
3. **定期更新**: 保持 chisel 工具最新版本
4. **监控日志**: 定期检查访问日志

## 与完整版本的区别

| 功能 | 极简版本 | 完整版本 |
|------|----------|----------|
| 文件数量 | 2 个脚本 | 14 个文件 |
| 配置复杂度 | 命令行参数 | 配置文件 |
| 功能完整性 | 核心功能 | 全部功能 |
| 学习成本 | 极低 | 中等 |
| 适用场景 | 快速部署 | 企业级管理 |

## 总结

极简版本的优势：
- 🚀 **一键部署** - 一个命令搞定所有操作
- 📦 **零配置** - 无需复杂的配置文件
- 🔧 **自动化** - 自动下载、安装、配置
- 💡 **易学习** - 5 分钟上手
- 🎯 **专注核心** - 只保留最常用功能

适合场景：
- 个人用户快速搭建代理
- 临时网络访问需求
- 简单的内网穿透
- 学习和测试 chisel 功能

如需更高级的功能（如集群管理、配置文件管理、systemd 服务等），请使用完整版本。
