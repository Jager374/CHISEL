#!/bin/bash

# Chisel 集群管理方案测试脚本
# 版本: 1.0
# 描述: 测试 chisel 集群管理方案的各项功能

set -eo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 测试计数器
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

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

log_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

# 测试函数
run_test() {
    local test_name="$1"
    local test_command="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log_test "执行测试: $test_name"

    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓ PASS${NC} - $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "  ${RED}✗ FAIL${NC} - $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# 检查文件存在性
test_file_exists() {
    local file="$1"
    local description="$2"
    run_test "$description" "[[ -f '$file' ]]"
}

# 检查脚本可执行性
test_script_executable() {
    local script="$1"
    local description="$2"
    run_test "$description" "[[ -x '$script' ]]"
}

# 检查配置文件语法
test_config_syntax() {
    local config="$1"
    local description="$2"
    run_test "$description" "source '$config'"
}

# 主测试函数
main() {
    echo "=== Chisel 集群管理方案测试 ==="
    echo "测试时间: $(date)"
    echo

    # 1. 文件存在性测试
    echo "1. 检查核心文件..."
    test_file_exists "chisel-install.sh" "通用安装脚本存在"
    test_file_exists "chisel-user-setup.sh" "低权限用户安装脚本存在"
    test_file_exists "chisel-server.sh" "服务端脚本存在"
    test_file_exists "chisel-client.sh" "客户端脚本存在"
    test_file_exists "chisel-manager.sh" "管理脚本存在"
    test_file_exists "README.md" "主要说明文档存在"
    test_file_exists "README-LOW-PRIVILEGE.md" "低权限用户指南存在"
    echo

    # 2. 配置文件测试
    echo "2. 检查配置文件..."
    test_file_exists "chisel-server.conf" "服务端配置文件存在"
    test_file_exists "chisel-client.conf" "客户端配置文件存在"
    test_file_exists "users.json" "用户认证文件存在"
    echo

    # 3. systemd 服务文件测试
    echo "3. 检查 systemd 服务文件..."
    test_file_exists "chisel-server.service" "服务端 systemd 文件存在"
    test_file_exists "chisel-client.service" "客户端 systemd 文件存在"
    test_file_exists "chisel-client-user.service" "用户级 systemd 文件存在"
    echo

    # 4. 脚本可执行性测试
    echo "4. 检查脚本可执行权限..."
    test_script_executable "chisel-install.sh" "通用安装脚本可执行"
    test_script_executable "chisel-user-setup.sh" "低权限安装脚本可执行"
    test_script_executable "chisel-server.sh" "服务端脚本可执行"
    test_script_executable "chisel-client.sh" "客户端脚本可执行"
    test_script_executable "chisel-manager.sh" "管理脚本可执行"
    echo

    # 5. 配置文件语法测试
    echo "5. 检查配置文件语法..."
    test_config_syntax "chisel-server.conf" "服务端配置语法正确"
    test_config_syntax "chisel-client.conf" "客户端配置语法正确"
    echo

    # 6. JSON 文件格式测试
    echo "6. 检查 JSON 文件格式..."
    run_test "用户认证 JSON 基本格式检查" "grep -q '{' users.json && grep -q '}' users.json"
    echo

    # 7. 脚本帮助信息测试
    echo "7. 检查脚本帮助信息..."
    run_test "服务端脚本帮助信息" "./chisel-server.sh --help"
    run_test "客户端脚本帮助信息" "./chisel-client.sh --help"
    run_test "管理脚本帮助信息" "./chisel-manager.sh help"
    echo

    # 8. 脚本基础功能测试
    echo "8. 检查脚本基础功能..."
    
    # 测试配置文件加载
    run_test "服务端配置加载测试" "bash -c 'source chisel-server.conf && [[ -n \"\$SERVER_HOST\" ]]'"
    run_test "客户端配置加载测试" "bash -c 'source chisel-client.conf && [[ -n \"\$SERVER_URL\" ]]'"
    
    # 测试脚本语法
    run_test "服务端脚本语法检查" "bash -n chisel-server.sh"
    run_test "客户端脚本语法检查" "bash -n chisel-client.sh"
    run_test "管理脚本语法检查" "bash -n chisel-manager.sh"
    run_test "安装脚本语法检查" "bash -n chisel-install.sh"
    echo

    # 9. 文档完整性测试
    echo "9. 检查文档完整性..."
    run_test "README 包含安装说明" "grep -q '快速开始' README.md"
    run_test "README 包含配置说明" "grep -q '详细配置' README.md"
    run_test "README 包含故障排除" "grep -q '故障排除' README.md"
    echo

    # 10. 安全配置测试
    echo "10. 检查安全配置..."
    run_test "服务端配置包含认证设置" "grep -q 'AUTH_' chisel-server.conf"
    run_test "客户端配置包含指纹验证" "grep -q 'FINGERPRINT' chisel-client.conf"
    run_test "用户文件包含示例用户" "grep -q 'admin:' users.json"
    echo

    # 测试结果汇总
    echo "=== 测试结果汇总 ==="
    echo "总测试数: $TESTS_TOTAL"
    echo -e "通过: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 所有测试通过！Chisel 集群管理方案已准备就绪。${NC}"
        echo
        echo "下一步操作："
        echo "1. 运行 ./chisel-install.sh 安装 chisel 工具"
        echo "2. 编辑配置文件设置服务器地址和认证信息"
        echo "3. 启动服务: ./chisel-server.sh start 或 ./chisel-client.sh start"
        echo "4. 使用管理工具: ./chisel-manager.sh status"
        return 0
    else
        echo -e "\n${RED}❌ 发现 $TESTS_FAILED 个问题，请检查并修复。${NC}"
        return 1
    fi
}

# 执行测试
main "$@"
