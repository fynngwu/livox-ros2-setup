#!/bin/bash
#
# Livox ROS2 Driver 一键安装脚本
# 适用于 Ubuntu 22.04 + ROS2 Humble
# 支持 Livox Mid-360 激光雷达
#

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root
check_sudo() {
    if [ "$EUID" -eq 0 ]; then
        print_error "请不要使用 sudo 运行此脚本"
        exit 1
    fi
}

# 检查 ROS2 环境
check_ros2() {
    print_info "检查 ROS2 环境..."

    if ! command -v ros2 &> /dev/null; then
        print_error "未找到 ROS2，请先安装 ROS2 Humble"
        exit 1
    fi

    local ros_distro=$(echo $ROS_DISTRO)
    if [ "$ros_distro" != "humble" ]; then
        print_warn "当前 ROS 版本是 $ros_distro，脚本针对 Humble 优化"
    fi

    print_info "ROS2 环境检查通过: $ros_distro"
}

# 安装依赖
install_dependencies() {
    print_info "安装依赖..."

    sudo apt update
    sudo apt install -y cmake git python3-colcon-common-extensions \
        libpcl-dev libeigen3-dev libboost-dev \
        ros-humble-pcl-conversions ros-humble-pcl-ros

    print_info "依赖安装完成"
}

# 创建工作空间
create_workspace() {
    print_info "创建工作空间..."

    WORKSPACE=~/livox_ws
    rm -rf $WORKSPACE
    mkdir -p $WORKSPACE/src
    cd $WORKSPACE

    print_info "工作空间创建完成: $WORKSPACE"
}

# 克隆并修复 Livox SDK2
setup_sdk2() {
    print_info "设置 Livox SDK2..."

    cd $WORKSPACE/src
    git clone https://github.com/Livox-SDK/Livox-SDK2.git

    # 修复 thread_base.h (路径已更新: sdk_core/src/base -> sdk_core/base)
    print_info "修复 Livox SDK2 thread_base.h..."
    sed -i '/#include <pthread.h>/a #include <cstring>' \
        Livox-SDK2/sdk_core/base/thread_base.h

    # 修复 thread_base.cpp
    print_info "修复 Livox SDK2 thread_base.cpp..."
    sed -i '/#include "thread_base.h"/a #include <unistd.h>' \
        Livox-SDK2/sdk_core/base/thread_base.cpp

    # 编译并安装
    print_info "编译 Livox SDK2..."
    cd Livox-SDK2
    mkdir -p build && cd build
    cmake .. > /dev/null
    make -j$(nproc) > /dev/null

    print_info "安装 Livox SDK2 (需要 sudo)..."
    sudo make install > /dev/null
    sudo ldconfig

    print_info "Livox SDK2 安装完成"
}

# 克隆并修复 livox_ros_driver2
setup_driver() {
    print_info "设置 livox_ros_driver2..."

    cd $WORKSPACE/src
    git clone https://github.com/Livox-SDK/livox_ros_driver2.git

    # 复制 package.xml
    print_info "复制 package.xml..."
    cp livox_ros_driver2/package_ROS2.xml livox_ros_driver2/package.xml

    # 修复 CMakeLists.txt
    print_info "修复 CMakeLists.txt..."

    # 创建 Python 脚本来修复 CMakeLists.txt
    python3 << 'PYTHON_SCRIPT'
import os

cmake_file = os.path.expanduser("~/livox_ws/src/livox_ros_driver2/CMakeLists.txt")

# 读取文件
with open(cmake_file, 'r') as f:
    content = f.read()

# 修复: 改进 HUMBLE_ROS 检查
old_check = '''  # get include directories of custom msg headers
  if(HUMBLE_ROS STREQUAL "humble")
    rosidl_get_typesupport_target(cpp_typesupport_target
    ${LIVOX_INTERFACES} "rosidl_typesupport_cpp")
    target_link_libraries(${PROJECT_NAME} "${cpp_typesupport_target}")
  else()
    set(LIVOX_INTERFACE_TARGET "${LIVOX_INTERFACES}__rosidl_typesupport_cpp")
    add_dependencies(${PROJECT_NAME} ${LIVOX_INTERFACES})
    get_target_property(LIVOX_INTERFACES_INCLUDE_DIRECTORIES ${LIVOX_INTERFACE_TARGET} INTERFACE_INCLUDE_DIRECTORIES)
  endif()

  # include file direcotry
  target_include_directories(${PROJECT_NAME} PUBLIC
    ${PCL_INCLUDE_DIRS}
    ${APR_INCLUDE_DIRS}
    ${LIVOX_LIDAR_SDK_INCLUDE_DIR}
    ${LIVOX_INTERFACES_INCLUDE_DIRECTORIES}   # for custom msgs
    3rdparty
    src
  )'''

new_check = '''  # get include directories of custom msg headers
  # For ROS2 Humble and later, use rosidl_get_typesupport_target
  rosidl_get_typesupport_target(cpp_typesupport_target
    ${LIVOX_INTERFACES} "rosidl_typesupport_cpp")
  if(TARGET "${cpp_typesupport_target}")
    target_link_libraries(${PROJECT_NAME} "${cpp_typesupport_target}")
  endif()

  # include file directory
  target_include_directories(${PROJECT_NAME} PUBLIC
    ${PCL_INCLUDE_DIRS}
    ${APR_INCLUDE_DIRS}
    ${LIVOX_LIDAR_SDK_INCLUDE_DIR}
    3rdparty
    src
  )'''

content = content.replace(old_check, new_check)

# 写回文件
with open(cmake_file, 'w') as f:
    f.write(content)

print("CMakeLists.txt 修复完成")
PYTHON_SCRIPT

    print_info "livox_ros_driver2 设置完成"
}

# 编译驱动
build_driver() {
    print_info "编译 livox_ros_driver2..."

    cd $WORKSPACE
    colcon build --packages-select livox_ros_driver2 --symlink-install

    print_info "编译完成"
}

# 配置环境变量
setup_environment() {
    print_info "配置环境变量..."

    # 检查是否已添加
    if ! grep -q "source ~/livox_ws/install/setup.bash" ~/.bashrc; then
        echo '' >> ~/.bashrc
        echo '# Livox ROS2 Driver' >> ~/.bashrc
        echo 'source ~/livox_ws/install/setup.bash' >> ~/.bashrc
        print_info "已添加到 ~/.bashrc"
    else
        print_info "已存在于 ~/.bashrc 中"
    fi

    # 当前 shell 生效
    source $WORKSPACE/install/setup.bash
}

# 验证安装
verify_installation() {
    print_info "验证安装..."

    source $WORKSPACE/install/setup.bash

    # 检查包
    if ros2 pkg list | grep -q livox_ros_driver2; then
        print_info "✓ 包检查通过"
    else
        print_error "✗ 包检查失败"
        return 1
    fi

    # 检查接口（使用 ros2 interface package 避免管道断裂警告）
    if ros2 interface package livox_ros_driver2 &>/dev/null; then
        print_info "✓ 接口检查通过"
    else
        print_error "✗ 接口检查失败"
        return 1
    fi

    print_info "验证完成！"
}

# 显示使用说明
show_usage() {
    cat << EOF

${GREEN}========================================
Livox ROS2 Driver 安装完成！
========================================${NC}

${YELLOW}工作空间位置:${NC} ~/livox_ws

${YELLOW}配置文件:${NC}
  - Mid-360: ~/livox_ws/src/livox_ros_driver2/config/MID360_config.json

${YELLOW}使用方法:${NC}
  1. 打开新终端 (环境变量已自动加载)
  2. 运行驱动: ros2 launch livox_ros_driver2 msg_MID360_launch.py

${YELLOW}在其他包中使用:${NC}
  CMakeLists.txt:
    find_package(livox_ros_driver2 REQUIRED)
    ament_target_dependencies(your_node rclcpp livox_ros_driver2)

  package.xml:
    <depend>livox_ros_driver2</depend>

  C++:
    #include <livox_ros_driver2/msg/custom_msg.hpp>

${YELLOW}重要提示:${NC}
  默认网络配置是 192.168.1.x 网段
  如需修改，请编辑 MID360_config.json

${YELLOW}验证安装:${NC}
  ros2 pkg list | grep livox
  ros2 interface show livox_ros_driver2/msg/CustomMsg

${GREEN}========================================${NC}

EOF
}

# 主函数
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Livox ROS2 Driver 一键安装脚本${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    check_sudo
    check_ros2
    install_dependencies
    create_workspace
    setup_sdk2
    setup_driver
    build_driver
    setup_environment
    verify_installation
    show_usage

    echo -e "${GREEN}安装完成！${NC}"
}

# 运行主函数
main
