# Docker 国内镜像源配置指南

本文档记录 Docker 和相关服务的国内镜像源配置方法，加速下载和安装。

## 1. Docker Hub 镜像加速

编辑 `/etc/docker/daemon.json`：

```json
{
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.xuanyuan.me"
  ]
}
```

重启 Docker 服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

验证配置：

```bash
docker info | grep -A 5 "Registry Mirrors"
```

## 2. Ubuntu APT 源（中科大）

```bash
# Ubuntu 22.04
sudo sed -i 's|http://archive.ubuntu.com|https://mirrors.ustc.edu.cn|g' /etc/apt/sources.list
sudo sed -i 's|http://security.ubuntu.com|https://mirrors.ustc.edu.cn|g' /etc/apt/sources.list
sudo apt update
```

## 3. ROS2 源（阿里云）

```bash
# ROS2 Humble
sudo sed -i 's|http://packages.ros.org/ros2/ubuntu|https://mirrors.aliyun.com/ros2/ubuntu|g' /usr/share/ros-apt-source/ros2.sources
```

## 4. pip 源（清华）

```bash
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
```

## 5. npm 源（淘宝）

```bash
npm config set registry https://registry.npmmirror.com
```

## 常用镜像源列表

| 服务 | 镜像源 | 官方地址 |
|------|--------|----------|
| Docker Hub | docker.1ms.run | hub.docker.com |
| Ubuntu APT | mirrors.ustc.edu.cn | archive.ubuntu.com |
| ROS2 | mirrors.aliyun.com/ros2 | packages.ros.org |
| pip | pypi.tuna.tsinghua.edu.cn | pypi.org |
| npm | registry.npmmirror.com | registry.npmjs.org |

## Dockerfile 示例

参见本仓库的 `Dockerfile.livox-test`，展示了如何在 Dockerfile 中配置镜像源。