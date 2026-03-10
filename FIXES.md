# Livox ROS2 Driver 安装修复文档

**日期**: 2026-03-10
**目标**: 配置 livox_ros_driver2 使其可通过 find_package 和 ROS2 interface 找到，支持 Mid-360 激光雷达

## 环境信息
- 系统: Ubuntu 22.04 (WSL2)
- ROS2: Humble
- 激光雷达: Livox Mid-360
- 工作空间: ~/livox_ws

## 遇到的问题及修复

### 问题 1: Livox SDK 缺少头文件

**错误信息**:
```
error: 'shared_ptr' in namespace 'std' does not name a template type
```

**原因**: Livox SDK2 的 `thread_base.h` 和 `thread_base.cpp` 缺少 `#include <memory>`

**修复**:

文件: `Livox-SDK2/sdk_core/src/base/thread_base.h`
```cpp
#ifndef LIVOX_THREAD_BASE_H_
#define LIVOX_THREAD_BASE_H_
#include <atomic>
#include <memory>      // 添加这一行
#include <thread>
#include "noncopyable.h"
```

文件: `Livox-SDK2/sdk_core/src/base/thread_base.cpp`
```cpp
#include "thread_base.h"
#include <memory>      // 添加这一行
#include <thread>
```

### 问题 2: livox_ros_driver2 缺少 package.xml

**错误信息**:
```
CMake Error: File /home/wufy/livox_ws/src/livox_ros_driver2/package.xml does not exist.
```

**原因**: 仓库中只有 `package_ROS1.xml` 和 `package_ROS2.xml`，没有 `package.xml`

**修复**:
```bash
cp ~/livox_ws/src/livox_ros_driver2/package_ROS2.xml \
   ~/livox_ws/src/livox_ros_driver2/package.xml
```

### 问题 3: livox_ros_driver2 CMakeLists.txt HUMBLE_ROS 变量未定义

**错误信息**:
```
CMake Error: The following variables are used in this project, but they are set to NOTFOUND:
/home/wufy/livox_ws/src/livox_ros_driver2/LIVOX_INTERFACES_INCLUDE_DIRECTORIES
```

**原因**: CMakeLists.txt 第 285 行检查 `HUMBLE_ROS STREQUAL "humble"`，但变量从未定义，导致走错误的分支

**修复**: 修改 `livox_ros_driver2/CMakeLists.txt` 第 284-303 行

**原代码**:
```cmake
  # get include directories of custom msg headers
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
  )
```

**修复后代码**:
```cmake
  # get include directories of custom msg headers
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
  )
```

## 完整安装步骤

### 1. 安装依赖
```bash
sudo apt update
sudo apt install -y cmake git
```

### 2. 克隆并修复 Livox SDK2
```bash
# 克隆 SDK2
git clone https://github.com/Livox-SDK/Livox-SDK2.git ~/livox_ws/src/Livox-SDK2

# 修复 thread_base.h
sed -i '/#include <atomic>/a #include <memory>' \
    ~/livox_ws/src/Livox-SDK2/sdk_core/src/base/thread_base.h

# 修复 thread_base.cpp
sed -i '/#include "thread_base.h"/a #include <memory>' \
    ~/livox_ws/src/Livox-SDK2/sdk_core/src/base/thread_base.cpp

# 编译并安装 SDK2
cd ~/livox_ws/src/Livox-SDK2
mkdir -p build && cd build
cmake .. && make -j$(nproc)
sudo make install
sudo ldconfig
```

### 3. 克隆并修复 livox_ros_driver2
```bash
# 克隆驱动
git clone https://github.com/Livox-SDK/livox_ros_driver2.git ~/livox_ws/src/livox_ros_driver2

# 复制 package.xml
cp ~/livox_ws/src/livox_ros_driver2/package_ROS2.xml \
   ~/livox_ws/src/livox_ros_driver2/package.xml

# 修复 CMakeLists.txt
cd ~/livox_ws/src/livox_ros_driver2
```

手动编辑 CMakeLists.txt 第 284-303 行，或使用一键安装脚本。

### 4. 编译驱动
```bash
cd ~/livox_ws
colcon build --packages-select livox_ros_driver2 --symlink-install
```

### 5. 配置环境变量
```bash
# 添加到 .bashrc
echo '' >> ~/.bashrc
echo '# Livox ROS2 Driver' >> ~/.bashrc
echo 'source ~/livox_ws/install/setup.bash' >> ~/.bashrc

# 当前 shell 生效
source ~/.livox_ws/install/setup.bash
```

### 6. 验证安装
```bash
# 检查包
ros2 pkg list | grep livox
# 输出: livox_ros_driver2

# 检查接口
ros2 interface list | grep livox
# 输出: livox_ros_driver2/msg/CustomMsg
#       livox_ros_driver2/msg/CustomPoint

# 查看消息定义
ros2 interface show livox_ros_driver2/msg/CustomMsg
```

## 在其他包中使用

### CMakeLists.txt
```cmake
find_package(livox_ros_driver2 REQUIRED)

add_executable(your_node src/node.cpp)
ament_target_dependencies(your_node
  rclcpp
  livox_ros_driver2
)
```

### package.xml
```xml
<depend>livox_ros_driver2</depend>
```

### C++ 代码
```cpp
#include <livox_ros_driver2/msg/custom_msg.hpp>

auto sub = create_subscription<livox_ros_driver2::msg::CustomMsg>(
  "/livox/lidar", 10, callback);
```

## 运行驱动

```bash
# 运行 Mid-360 驱动
ros2 launch livox_ros_driver2 msg_MID360_launch.py
```

**注意**: 首次运行前需要修改网络配置（默认 192.168.1.x 网段）。

## 网络配置

配置文件: `~/livox_ws/src/livox_ros_driver2/config/MID360_config.json`

默认配置:
- 雷达 IP: 192.168.1.12
- 主机 IP: 192.168.1.5

如果使用其他网段，需要修改配置文件中的 IP 地址。
