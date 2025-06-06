#!/bin/bash

# Chisel 极简版本测试脚本
# 版本: 2.0
# 描述: 测试极简版本的功能

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

# 主测试函数
main() {
    echo "=== Chisel 极简版本测试 ==="
    echo "测试时间: $(date)"
    echo

    # 1. 文件存在性测试
    echo "1. 检查核心文件..."
    run_test "客户端脚本存在" "[[ -f 'chisel-simple.sh' ]]"
    run_test "服务端脚本存在" "[[ -f 'chisel-server-simple.sh' ]]"
    run_test "极简使用指南存在" "[[ -f 'README-SIMPLE.md' ]]"
    echo

    # 2. 脚本可执行性测试
    echo "2. 检查脚本可执行权限..."
    run_test "客户端脚本可执行" "[[ -x 'chisel-simple.sh' ]]"
    run_test "服务端脚本可执行" "[[ -x 'chisel-server-simple.sh' ]]"
    echo

    # 3. 脚本语法测试
    echo "3. 检查脚本语法..."
    run_test "客户端脚本语法正确" "bash -n chisel-simple.sh"
    run_test "服务端脚本语法正确" "bash -n chisel-server-simple.sh"
    echo

    # 4. 帮助信息测试
    echo "4. 检查帮助信息..."
    run_test "客户端帮助信息" "./chisel-simple.sh help"
    run_test "服务端帮助信息" "./chisel-server-simple.sh help"
    echo

    # 5. 基础功能测试
    echo "5. 检查基础功能..."
    run_test "客户端状态命令" "./chisel-simple.sh status"
    run_test "服务端状态命令" "./chisel-server-simple.sh status"
    echo

    # 6. 文档完整性测试
    echo "6. 检查文档完整性..."
    run_test "极简指南包含快速开始" "grep -q '快速开始' README-SIMPLE.md"
    run_test "极简指南包含使用场景" "grep -q '使用场景' README-SIMPLE.md"
    run_test "极简指南包含命令参考" "grep -q '命令参考' README-SIMPLE.md"
    echo

    # 7. 功能特性测试
    echo "7. 检查功能特性..."
    run_test "客户端支持 SOCKS5" "grep -q 'socks' chisel-simple.sh"
    run_test "客户端支持端口转发" "grep -q 'localhost:' chisel-simple.sh"
    run_test "服务端支持认证" "grep -q 'auth' chisel-server-simple.sh"
    run_test "服务端支持用户管理" "grep -q 'users' chisel-server-simple.sh"
    echo

    # 8. 安全特性测试
    echo "8. 检查安全特性..."
    run_test "客户端支持认证" "grep -q 'auth' chisel-simple.sh"
    run_test "服务端创建用户文件" "grep -q 'users.json' chisel-server-simple.sh"
    echo

    # 测试结果汇总
    echo "=== 测试结果汇总 ==="
    echo "总测试数: $TESTS_TOTAL"
    echo -e "通过: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "失败: ${RED}$TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}🎉 所有测试通过！极简版本已准备就绪。${NC}"
        echo
        echo "快速使用："
        echo "1. 客户端: ./chisel-simple.sh start http://server:8080 user:pass socks"
        echo "2. 服务端: ./chisel-server-simple.sh start 8080"
        echo "3. 查看状态: ./chisel-simple.sh status"
        echo "4. 配置向导: ./chisel-simple.sh config"
        return 0
    else
        echo -e "\n${RED}❌ 发现 $TESTS_FAILED 个问题，请检查并修复。${NC}"
        return 1
    fi
}

# 执行测试
main "$@"
