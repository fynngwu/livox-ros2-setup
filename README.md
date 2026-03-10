# Livox ROS2 Driver 工作空间

## 安装位置
- 工作空间: `~/livox_ws`
- 驱动版本: livox_ros_driver2
- SDK版本: Livox SDK2

## 使用方法

### 1. Source 环境变量
```bash
source ~/livox_ws/install/setup.bash
```

注意：该命令已添加到 `~/.bashrc` 中，新终端会自动 source。

### 2. 运行驱动 (Mid-360)
```bash
ros2 launch livox_ros_driver2 msg_MID360_launch.py
```

### 3. 在其他包中使用

**CMakeLists.txt:**
```cmake
find_package(livox_ros_driver2 REQUIRED)
ament_target_dependencies(your_node
  rclcpp
  livox_ros_driver2
)
```

**package.xml:**
```xml
<depend>livox_ros_driver2</depend>
```

**C++ 代码:**
```cpp
#include <livox_ros_driver2/msg/custom_msg.hpp>

auto sub = create_subscription<livox_ros_driver2::msg::CustomMsg>(
  "/livox/lidar", 10, callback);
```

### 4. 发布的话题
- `/livox/lidar` - CustomMsg 类型
- `/livox/lidar_point_cloud` - PointCloud2 类型

## 配置文件
- Mid-360 配置: `src/livox_ros_driver2/config/MID360_config.json`
- 默认雷达IP: 192.168.1.12
- 默认主机IP: 192.168.1.5

**重要**: 使用前请根据你的网络配置修改 `MID360_config.json` 中的 IP 地址。

## 网络配置示例
如果当前网络是 `172.25.108.x`，需要：
1. 添加一个静态IP到 `192.168.1.x` 网段，或
2. 修改配置文件中的所有 IP 地址

## 修改记录
- 修复了 Livox SDK2 的 thread_base.h/cpp 缺少 `#include <memory>` 问题
- 修复了 livox_ros_driver2 的 CMakeLists.txt 中 HUMBLE_ROS 变量未定义问题
